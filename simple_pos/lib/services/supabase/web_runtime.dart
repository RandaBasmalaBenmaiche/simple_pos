import 'package:flutter/foundation.dart';

import 'supabase_project_config.dart';

bool get useSupabaseWeb => kIsWeb && SupabaseProjectConfig.isConfigured;
