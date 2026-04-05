import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

typedef DatabaseClient = HiveDatabase;

class HiveDatabase {
  HiveDatabase._(this.name);

  final String name;
  final Map<String, Box<dynamic>> _boxes = {};
  Future<void> _transactionQueue = Future<void>.value();
  static Future<void>? _initFuture;

  static Future<HiveDatabase> open(String name) async {
    _initFuture ??= Hive.initFlutter(name);
    await _initFuture;
    return HiveDatabase._(name);
  }

  Future<Box<dynamic>> openBox(String boxName) async {
    final existing = _boxes[boxName];
    if (existing != null && existing.isOpen) {
      return existing;
    }

    final box = await Hive.openBox<dynamic>(boxName);
    _boxes[boxName] = box;
    return box;
  }

  Future<T> transaction<T>(Future<T> Function(DatabaseClient txn) action) {
    final completer = Completer<T>();
    _transactionQueue = _transactionQueue.then((_) async {
      try {
        final result = await action(this);
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> close() async {
    for (final box in _boxes.values) {
      if (box.isOpen) {
        await box.close();
      }
    }
    _boxes.clear();
  }

  Future<void> delete() async {
    final names = _boxes.keys.toList();
    await close();
    for (final boxName in names) {
      await Hive.deleteBoxFromDisk(boxName);
    }
  }
}

class RecordSnapshot<K, V> {
  const RecordSnapshot(this.key, this.value);

  final K key;
  final V value;
}

class SortOrder {
  const SortOrder(this.field, {this.ascending = true});

  final String field;
  final bool ascending;
}

abstract class Filter {
  const Filter();

  bool matches(Map<String, dynamic> value);

  factory Filter.equals(String field, Object? expected) = _EqualsFilter;
  factory Filter.and(List<Filter> filters) = _AndFilter;
}

class _EqualsFilter extends Filter {
  const _EqualsFilter(this.field, this.expected);

  final String field;
  final Object? expected;

  @override
  bool matches(Map<String, dynamic> value) => value[field] == expected;
}

class _AndFilter extends Filter {
  const _AndFilter(this.filters);

  final List<Filter> filters;

  @override
  bool matches(Map<String, dynamic> value) {
    for (final filter in filters) {
      if (!filter.matches(value)) return false;
    }
    return true;
  }
}

class Finder {
  const Finder({
    this.filter,
    this.sortOrders,
    this.limit,
  });

  final Filter? filter;
  final List<SortOrder>? sortOrders;
  final int? limit;
}

class _RecordRef<K, V> {
  const _RecordRef(this.store, this.key);

  final StoreRef<K, V> store;
  final K key;

  Future<V?> get(DatabaseClient client) => store.getRecord(client, key);

  Future<void> put(DatabaseClient client, V value) =>
      store.putRecord(client, key, value);

  Future<void> delete(DatabaseClient client) => store.deleteRecord(client, key);
}

class StoreRef<K, V> {
  const StoreRef(this.name);

  final String name;

  _RecordRef<K, V> record(K key) => _RecordRef<K, V>(this, key);

  Future<int> count(DatabaseClient client) async {
    final box = await client.openBox(name);
    return box.length;
  }

  Future<List<RecordSnapshot<K, V>>> find(
    DatabaseClient client, {
    Finder? finder,
  }) async {
    final box = await client.openBox(name);
    final snapshots = <RecordSnapshot<K, V>>[];

    for (final key in box.keys) {
      final rawValue = box.get(key);
      if (rawValue == null) continue;
      final normalizedValue = _normalizeValue(rawValue);
      if (finder?.filter != null && !finder!.filter!.matches(normalizedValue)) {
        continue;
      }
      snapshots.add(
        RecordSnapshot<K, V>(key as K, normalizedValue as V),
      );
    }

    final sortOrders = finder?.sortOrders;
    if (sortOrders != null && sortOrders.isNotEmpty) {
      snapshots.sort((a, b) {
        for (final order in sortOrders) {
          final left = _fieldValue(a.value, order.field);
          final right = _fieldValue(b.value, order.field);
          final result = _compareValues(left, right);
          if (result != 0) {
            return order.ascending ? result : -result;
          }
        }
        return 0;
      });
    }

    final limit = finder?.limit;
    if (limit != null && snapshots.length > limit) {
      return snapshots.take(limit).toList();
    }

    return snapshots;
  }

  Future<V?> getRecord(DatabaseClient client, K key) async {
    final box = await client.openBox(name);
    final rawValue = box.get(key);
    if (rawValue == null) return null;
    return _normalizeValue(rawValue) as V;
  }

  Future<void> putRecord(DatabaseClient client, K key, V value) async {
    final box = await client.openBox(name);
    await box.put(key, _prepareForStorage(value));
  }

  Future<void> deleteRecord(DatabaseClient client, K key) async {
    final box = await client.openBox(name);
    await box.delete(key);
  }

  static dynamic _prepareForStorage(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map((key, value) => MapEntry(key.toString(), _prepareForStorage(value))),
      );
    }
    if (value is List) {
      return value.map(_prepareForStorage).toList();
    }
    return value;
  }

  static dynamic _normalizeValue(dynamic value) {
    if (value is Map) {
      return Map<String, Object?>.from(
        value.map((key, value) => MapEntry(key.toString(), _normalizeValue(value))),
      );
    }
    if (value is List) {
      return value.map(_normalizeValue).toList();
    }
    return value;
  }

  static dynamic _fieldValue(dynamic value, String field) {
    if (value is Map) {
      return value[field];
    }
    return null;
  }

  static int _compareValues(dynamic left, dynamic right) {
    if (left == null && right == null) return 0;
    if (left == null) return -1;
    if (right == null) return 1;

    if (left is Comparable && right is Comparable) {
      try {
        return left.compareTo(right);
      } catch (_) {
        return left.toString().compareTo(right.toString());
      }
    }

    return left.toString().compareTo(right.toString());
  }
}

class _IntMapStoreFactory {
  const _IntMapStoreFactory();

  StoreRef<int, Map<String, Object?>> store(String name) =>
      StoreRef<int, Map<String, Object?>>(name);
}

const intMapStoreFactory = _IntMapStoreFactory();

Future<void> deleteHiveDatabase(HiveDatabase db) async {
  await db.delete();
  if (!kIsWeb) {
    await Hive.close();
  }
}
