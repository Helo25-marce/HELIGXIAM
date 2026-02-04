-- =====================================================
-- EXTENSIONS
-- =====================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto"; -- gen_random_uuid()

-- =====================================================
-- ENUMS (plus propre que VARCHAR libre)
-- =====================================================
CREATE TYPE user_role AS ENUM ('client','vendeur','admin');
CREATE TYPE order_status AS ENUM ('pending','confirmed','shipped','delivered','canceled');
CREATE TYPE payment_status AS ENUM ('pending','success','failed');
CREATE TYPE address_type AS ENUM ('billing','shipping');

-- =====================================================
-- 1. USERS SERVICE (3001)
-- Correspond : /auth + /users
-- =====================================================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    username VARCHAR(30) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,

    role user_role NOT NULL DEFAULT 'client',

    created_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP NULL
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);

-- =====================================================
-- 2. ADDRESSES SERVICE (3006)
-- Correspond : /addresses
-- =====================================================

CREATE TABLE addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    type address_type NOT NULL,

    line1 VARCHAR(255) NOT NULL,
    line2 VARCHAR(255),
    city VARCHAR(120) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    country VARCHAR(2) NOT NULL, -- ISO code FR, US...

    is_default BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_addresses_user ON addresses(user_id);

-- =====================================================
-- 3. ORDERS SERVICE (3003)
-- Correspond : /orders
-- =====================================================

CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID NOT NULL REFERENCES users(id),

    shipping_address_id UUID NOT NULL REFERENCES addresses(id),
    billing_address_id UUID NOT NULL REFERENCES addresses(id),

    status order_status NOT NULL DEFAULT 'pending',

    total_amount NUMERIC(12,2) NOT NULL CHECK (total_amount >= 0),
    currency VARCHAR(5) DEFAULT 'EUR',

    coupon_code VARCHAR(50),

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);

-- =====================================================
-- 3.1 ORDER ITEMS
-- (référence productId Mongo uniquement par UUID)
-- =====================================================

CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,

    product_id UUID NOT NULL, -- MongoDB reference
    name VARCHAR(255) NOT NULL, -- snapshot du nom
    price NUMERIC(12,2) NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0)
);

CREATE INDEX idx_items_order ON order_items(order_id);

-- =====================================================
-- 4. PAYMENTS SERVICE (3005)
-- Correspond : /payments
-- =====================================================

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_id UUID UNIQUE NOT NULL REFERENCES orders(id) ON DELETE CASCADE,

    provider VARCHAR(30) NOT NULL, -- stripe/paypal
    payment_method VARCHAR(50),

    status payment_status NOT NULL DEFAULT 'pending',

    amount NUMERIC(12,2) NOT NULL,
    currency VARCHAR(5) DEFAULT 'EUR',

    transaction_id VARCHAR(255),

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_payments_status ON payments(status);

-- =====================================================
-- 5. OPTIONAL : REVIEWS (si tu veux garder avis en SQL)
-- sinon peut rester Mongo
-- =====================================================

CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    product_id UUID NOT NULL, -- Mongo ref

    rating INT CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,

    created_at TIMESTAMP DEFAULT NOW()
);

-- =====================================================
-- TRIGGERS auto update timestamp
-- =====================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_orders_updated
BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_payments_updated
BEFORE UPDATE ON payments
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
