-- Create product_aliases table
CREATE TABLE product_aliases (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    sync_id UUID NOT NULL UNIQUE,
    product_sync_id UUID NOT NULL,
    alias_name TEXT NOT NULL,
    store_sync_id UUID NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_synced_at TIMESTAMPTZ,
    device_id TEXT,

    -- Foreign key to stock table referencing sync_id
    CONSTRAINT fk_product FOREIGN KEY (product_sync_id) REFERENCES stock(sync_id) ON DELETE CASCADE,
    -- Foreign key to stores table referencing sync_id
    CONSTRAINT fk_store FOREIGN KEY (store_sync_id) REFERENCES stores(sync_id) ON DELETE CASCADE
);

-- Index for faster alias lookup
CREATE INDEX idx_product_aliases_name_store ON product_aliases (alias_name, store_sync_id);
