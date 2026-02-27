-- ===============================
-- WATCH STORE DATABASE (PostgreSQL)
-- Final Production Version (Combined & Optimized)
-- ===============================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. ENUM TYPES
CREATE TYPE user_role AS ENUM ('admin', 'customer');

CREATE TYPE order_status AS ENUM (
    'pending',
    'paid',
    'shipped',
    'completed',
    'cancelled'
);

CREATE TYPE payment_status AS ENUM (
    'pending',
    'success',
    'failed'
);

CREATE TYPE payment_method AS ENUM (
    'cod',
    'momo',
    'vnpay',
    'bank_transfer'
);

CREATE TYPE inventory_transaction_type AS ENUM (
    'import',      -- Nhập hàng
    'export',      -- Xuất hàng (ngoài bán hàng)
    'adjustment',  -- Điều chỉnh (do hư hỏng, mất mát)
    'sale'         -- Xuất do bán hàng
);

-- 2. TABLES

-- USERS
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    role user_role DEFAULT 'customer',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- BRANDS
CREATE TABLE brands (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

-- CATEGORIES
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL
);

-- WATCHES
CREATE TABLE watches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price NUMERIC(12,2) NOT NULL CHECK (price >= 0),
    stock INT DEFAULT 0 CHECK (stock >= 0), -- Số lượng tồn thực tế
    brand_id INT REFERENCES brands(id),
    category_id INT REFERENCES categories(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- WATCH IMAGES (Thêm mới để hỗ trợ UI Flutter)
CREATE TABLE watch_images (
    id SERIAL PRIMARY KEY,
    watch_id UUID REFERENCES watches(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    is_primary BOOLEAN DEFAULT false
);

-- INVENTORY LOGS (Quản lý nhập xuất kho - Cực quan trọng cho CV)
CREATE TABLE inventory_logs (
    id SERIAL PRIMARY KEY,
    watch_id UUID REFERENCES watches(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id), -- Người thực hiện (admin)
    quantity INT NOT NULL, 
    type inventory_transaction_type NOT NULL,
    note TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- CART
CREATE TABLE cart (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    watch_id UUID REFERENCES watches(id) ON DELETE CASCADE,
    quantity INT DEFAULT 1 CHECK (quantity > 0),
    PRIMARY KEY (user_id, watch_id)
);

-- ORDERS
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    total_amount NUMERIC(12,2) NOT NULL CHECK (total_amount >= 0),
    status order_status DEFAULT 'pending',
    shipping_address TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ORDER ITEMS (Sửa lại: Có cả ID sản phẩm và Snapshot thông tin lúc mua)
CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    watch_id UUID REFERENCES watches(id) ON DELETE SET NULL, -- Giữ lại ID để thống kê
    watch_name VARCHAR(200) NOT NULL, -- Snapshot tên lúc mua
    price_at_purchase NUMERIC(12,2) NOT NULL CHECK (price_at_purchase >= 0),
    quantity INT NOT NULL CHECK (quantity > 0)
);

-- ORDER STATUS HISTORY
CREATE TABLE order_status_history (
    id SERIAL PRIMARY KEY,
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    old_status order_status,
    new_status order_status NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- PAYMENTS
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
    method payment_method NOT NULL,
    status payment_status DEFAULT 'pending',
    paid_at TIMESTAMP
);