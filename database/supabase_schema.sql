-- ============================================================================
-- Blood Bridge - PostgreSQL / Supabase Database Schema
-- ============================================================================
-- This schema mirrors the Firestore data model and is designed for Supabase.
-- To use: Run this SQL in your Supabase SQL Editor, or adapt for standalone PostgreSQL.
--
-- Key design decisions:
-- 1. Snake_case column names (Supabase convention)
-- 2. UUID primary keys with auto-generation
-- 3. Row-Level Security (RLS) policies mirroring Firestore rules
-- 4. Timestamps with timezone
-- 5. Indexes on frequently queried columns
-- ============================================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. USERS TABLE
-- ============================================================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_id UUID UNIQUE,                         -- Supabase Auth user ID (references auth.users)
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    contact VARCHAR(50),
    blood_group VARCHAR(5),                      -- A+, A-, B+, B-, AB+, AB-, O+, O-
    role VARCHAR(20) NOT NULL DEFAULT 'user',    -- 'donor', 'recipient', 'admin', 'super_admin', 'blood_bank'
    location VARCHAR(500),
    designation VARCHAR(255),
    age INTEGER CHECK (age >= 18 AND age <= 65),
    gender VARCHAR(20),
    cnic VARCHAR(20),                            -- Pakistani CNIC: XXXXX-XXXXXXX-X
    approved BOOLEAN DEFAULT FALSE,
    is_donor BOOLEAN DEFAULT FALSE,
    first_donation_approved BOOLEAN,
    photo_data TEXT,                             -- Base64 encoded image
    verification_document_data TEXT,             -- Base64 encoded document
    verification_status VARCHAR(20) DEFAULT 'not_uploaded', -- 'not_uploaded', 'pending', 'approved', 'rejected'
    cooldown_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT chk_blood_group CHECK (blood_group IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')),
    CONSTRAINT chk_role CHECK (role IN ('donor', 'recipient', 'admin', 'super_admin', 'blood_bank'))
);

-- Indexes for common queries
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_blood_group ON users(blood_group);
CREATE INDEX idx_users_location ON users(location);
CREATE INDEX idx_users_approved ON users(approved);
CREATE INDEX idx_users_verification_status ON users(verification_status);

-- ============================================================================
-- 2. BLOOD REQUESTS TABLE (formerly donor_requests)
-- ============================================================================
CREATE TABLE blood_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type VARCHAR(30) NOT NULL DEFAULT 'donor_request', -- 'donor_request', 'donor_access_request', 'emergency'
    donor_email VARCHAR(255),
    donor_name VARCHAR(255),
    donor_id UUID REFERENCES users(id),
    requester_email VARCHAR(255),
    requester_name VARCHAR(255),
    recipient_email VARCHAR(255),
    recipient_name VARCHAR(255),
    blood_group VARCHAR(5),
    status VARCHAR(20) NOT NULL DEFAULT 'pending',    -- 'pending', 'approved', 'rejected', 'completed'
    message TEXT,
    location VARCHAR(500),
    urgency VARCHAR(20) DEFAULT 'normal',              -- 'normal', 'high', 'critical'
    units INTEGER DEFAULT 1,
    is_emergency BOOLEAN DEFAULT FALSE,
    response_message TEXT,
    requested_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    responded_at TIMESTAMPTZ,

    CONSTRAINT chk_request_status CHECK (status IN ('pending', 'approved', 'rejected', 'completed')),
    CONSTRAINT chk_urgency CHECK (urgency IN ('normal', 'high', 'critical'))
);

CREATE INDEX idx_blood_requests_status ON blood_requests(status);
CREATE INDEX idx_blood_requests_type ON blood_requests(type);
CREATE INDEX idx_blood_requests_donor_email ON blood_requests(donor_email);
CREATE INDEX idx_blood_requests_recipient_email ON blood_requests(recipient_email);
CREATE INDEX idx_blood_requests_requester_email ON blood_requests(requester_email);

-- ============================================================================
-- 3. CHAT MESSAGES TABLE
-- ============================================================================
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chat_id VARCHAR(255) NOT NULL,                    -- Composite: sorted user IDs, e.g. "uid1_uid2"
    sender_id UUID NOT NULL REFERENCES users(id),
    sender_name VARCHAR(255),
    receiver_id UUID NOT NULL REFERENCES users(id),
    receiver_name VARCHAR(255),
    message TEXT NOT NULL,
    read BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_messages_chat_id ON messages(chat_id);
CREATE INDEX idx_messages_sender_id ON messages(sender_id);
CREATE INDEX idx_messages_receiver_id ON messages(receiver_id);
CREATE INDEX idx_messages_sent_at ON messages(sent_at);

-- ============================================================================
-- 4. BROADCASTS TABLE
-- ============================================================================
CREATE TABLE broadcasts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message TEXT NOT NULL,
    target_audience VARCHAR(20) NOT NULL DEFAULT 'all', -- 'all', 'donors', 'recipients'
    sender_id UUID NOT NULL REFERENCES users(id),
    sender_name VARCHAR(255),
    sent_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_broadcasts_target ON broadcasts(target_audience);
CREATE INDEX idx_broadcasts_sent_at ON broadcasts(sent_at);

-- ============================================================================
-- 5. DONATIONS TABLE
-- ============================================================================
CREATE TABLE donations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    donor_id UUID NOT NULL REFERENCES users(id),
    donor_name VARCHAR(255),
    donor_email VARCHAR(255),
    recipient_id UUID REFERENCES users(id),
    recipient_name VARCHAR(255),
    blood_group VARCHAR(5),
    units INTEGER DEFAULT 1,
    donation_date TIMESTAMPTZ,
    location VARCHAR(500),
    notes TEXT,
    is_reminder BOOLEAN DEFAULT FALSE,              -- true = upcoming reminder, false = past donation
    reminder_date TIMESTAMPTZ,
    reminder_sent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_donations_donor_id ON donations(donor_id);
CREATE INDEX idx_donations_is_reminder ON donations(is_reminder);
CREATE INDEX idx_donations_reminder_sent ON donations(reminder_sent);

-- ============================================================================
-- 6. STORAGE FILES TABLE (metadata tracking)
-- ============================================================================
CREATE TABLE storage_files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    file_path VARCHAR(500) NOT NULL,
    file_type VARCHAR(20),                           -- 'profile_photo', 'verification_doc'
    content_type VARCHAR(100),
    file_size_bytes BIGINT,
    uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- ROW-LEVEL SECURITY (RLS) POLICIES
-- Enable RLS on all tables
-- ============================================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE blood_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE broadcasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE donations ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage_files ENABLE ROW LEVEL SECURITY;

-- Users: authenticated users can read all, can only write their own row
CREATE POLICY "Users can read all users" ON users
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can insert their own profile" ON users
    FOR INSERT WITH CHECK (auth.uid()::text = auth_id::text);

CREATE POLICY "Users can update their own profile" ON users
    FOR UPDATE USING (auth.uid()::text = auth_id::text);

-- Blood Requests: authenticated users can read, insert; update own
CREATE POLICY "Authenticated can read requests" ON blood_requests
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated can create requests" ON blood_requests
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update their own requests" ON blood_requests
    FOR UPDATE USING (
        auth.role() = 'authenticated' AND
        (requester_email = (SELECT email FROM users WHERE auth_id::text = auth.uid()::text) OR
         donor_email = (SELECT email FROM users WHERE auth_id::text = auth.uid()::text))
    );

-- Messages: users can read messages they sent or received
CREATE POLICY "Users can read their messages" ON messages
    FOR SELECT USING (
        auth.role() = 'authenticated' AND
        (sender_id = (SELECT id FROM users WHERE auth_id::text = auth.uid()::text) OR
         receiver_id = (SELECT id FROM users WHERE auth_id::text = auth.uid()::text))
    );

CREATE POLICY "Users can send messages" ON messages
    FOR INSERT WITH CHECK (
        auth.role() = 'authenticated' AND
        sender_id = (SELECT id FROM users WHERE auth_id::text = auth.uid()::text)
    );

-- Broadcasts: anyone authenticated can read; only admins can create
CREATE POLICY "Authenticated can read broadcasts" ON broadcasts
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can create broadcasts" ON broadcasts
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM users
            WHERE auth_id::text = auth.uid()::text
            AND role IN ('admin', 'super_admin')
        )
    );

-- Donations: authenticated can read; donors/admins can create
CREATE POLICY "Authenticated can read donations" ON donations
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can record donations" ON donations
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- ============================================================================
-- TRIGGER: Auto-update updated_at timestamp
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_blood_requests_updated_at
    BEFORE UPDATE ON blood_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- MULTI-TENANT TABLES (v2.0)
-- ============================================================================

-- 7. ORGANIZATIONS TABLE
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type VARCHAR(20) NOT NULL CHECK (type IN ('university', 'society', 'blood_bank', 'ngo')),
    name VARCHAR(255) NOT NULL,
    logo_url TEXT,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    address TEXT,
    city VARCHAR(100),
    province VARCHAR(100),
    website VARCHAR(255),
    description TEXT,
    license_number VARCHAR(100),
    university_id UUID REFERENCES organizations(id),
    admin_id VARCHAR(255),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'active', 'suspended', 'rejected')),
    subscription_id UUID,
    trial_end_date TIMESTAMPTZ,
    branding JSONB,
    settings JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_organizations_type ON organizations(type);
CREATE INDEX idx_organizations_status ON organizations(status);
CREATE INDEX idx_organizations_university_id ON organizations(university_id);

-- 8. SUBSCRIPTION PLANS TABLE
CREATE TABLE subscription_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL DEFAULT 0,
    currency VARCHAR(5) DEFAULT 'PKR',
    max_users INTEGER,
    max_societies INTEGER,
    max_admins INTEGER,
    max_blood_requests INTEGER,
    max_storage_mb INTEGER,
    features TEXT[] DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    trial_days INTEGER,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. SUBSCRIPTIONS TABLE
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    plan_id UUID NOT NULL REFERENCES subscription_plans(id),
    plan_name VARCHAR(100),
    start_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_date TIMESTAMPTZ,
    status VARCHAR(20) DEFAULT 'trial' CHECK (status IN ('trial', 'active', 'expiring_soon', 'expired', 'suspended', 'cancelled')),
    payment_status VARCHAR(20) DEFAULT 'not_required' CHECK (payment_status IN ('paid', 'pending', 'failed', 'not_required')),
    auto_renewal BOOLEAN DEFAULT FALSE,
    amount DECIMAL(10,2) DEFAULT 0,
    currency VARCHAR(5) DEFAULT 'PKR',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_subscriptions_org_id ON subscriptions(organization_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);

-- 10. PAYMENTS TABLE
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    subscription_id UUID NOT NULL REFERENCES subscriptions(id),
    invoice_id UUID,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(5) DEFAULT 'PKR',
    payment_method VARCHAR(30) DEFAULT 'manual',
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
    transaction_id VARCHAR(255),
    receipt_url TEXT,
    notes TEXT,
    payment_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_payments_org_id ON payments(organization_id);

-- 11. INVOICES TABLE
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    organization_id UUID NOT NULL REFERENCES organizations(id),
    organization_name VARCHAR(255),
    subscription_id UUID NOT NULL REFERENCES subscriptions(id),
    plan_name VARCHAR(100),
    payment_id UUID NOT NULL REFERENCES payments(id),
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(5) DEFAULT 'PKR',
    payment_method VARCHAR(30),
    transaction_id VARCHAR(255),
    invoice_date TIMESTAMPTZ DEFAULT NOW(),
    subscription_start_date TIMESTAMPTZ NOT NULL,
    subscription_end_date TIMESTAMPTZ,
    status VARCHAR(20) DEFAULT 'paid' CHECK (status IN ('paid', 'pending', 'cancelled')),
    metadata JSONB
);
CREATE INDEX idx_invoices_org_id ON invoices(organization_id);

-- 12. BLOOD INVENTORY TABLE
CREATE TABLE blood_inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    blood_bank_id UUID NOT NULL REFERENCES organizations(id),
    blood_group VARCHAR(5) NOT NULL CHECK (blood_group IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')),
    quantity INTEGER DEFAULT 0,
    unit VARCHAR(10) DEFAULT 'units',
    collection_date TIMESTAMPTZ NOT NULL,
    expiry_date TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) DEFAULT 'available' CHECK (status IN ('available', 'low_stock', 'expiring_soon', 'expired', 'used')),
    batch_number VARCHAR(100),
    donor_id UUID REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_blood_inventory_bank_id ON blood_inventory(blood_bank_id);
CREATE INDEX idx_blood_inventory_blood_group ON blood_inventory(blood_group);
CREATE INDEX idx_blood_inventory_status ON blood_inventory(status);

-- Add multi-tenant columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizations(id);
ALTER TABLE users ADD COLUMN IF NOT EXISTS university_id UUID REFERENCES organizations(id);
ALTER TABLE users ADD COLUMN IF NOT EXISTS society_id UUID REFERENCES organizations(id);
ALTER TABLE users ADD COLUMN IF NOT EXISTS blood_bank_id UUID REFERENCES organizations(id);

-- Add organization_id to blood_requests
ALTER TABLE blood_requests ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizations(id);

-- ============================================================================
-- RLS POLICIES FOR NEW TABLES
-- ============================================================================
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE blood_inventory ENABLE ROW LEVEL SECURITY;

-- Organizations: super admin can do everything; org admins can read their own
CREATE POLICY "Super admin full access" ON organizations FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE auth_id::text = auth.uid()::text AND role = 'super_admin')
);
CREATE POLICY "Org admin can read own org" ON organizations FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE auth_id::text = auth.uid()::text AND organization_id = organizations.id)
);

-- Subscription plans: anyone authenticated can read; only super admin can write
CREATE POLICY "Anyone can read plans" ON subscription_plans FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Super admin can write plans" ON subscription_plans FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM users WHERE auth_id::text = auth.uid()::text AND role = 'super_admin')
);

-- Blood inventory: blood bank admins can read/write their own
CREATE POLICY "Blood bank admins manage own inventory" ON blood_inventory FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE auth_id::text = auth.uid()::text AND blood_bank_id = blood_inventory.blood_bank_id)
);

-- ============================================================================
-- VIEW: Donor leaderboard (for gamification)
-- ============================================================================
CREATE VIEW donor_leaderboard AS
SELECT
    u.id,
    u.name,
    u.blood_group,
    u.location,
    COUNT(d.id) AS total_donations,
    COALESCE(SUM(d.units), 0) AS total_units,
    MAX(d.donation_date) AS last_donation_date
FROM users u
LEFT JOIN donations d ON u.id = d.donor_id AND d.is_reminder = FALSE
WHERE u.role = 'donor' AND u.approved = TRUE
GROUP BY u.id, u.name, u.blood_group, u.location
ORDER BY total_donations DESC;

-- ============================================================================
-- VIEW: Blood group stock summary
-- ============================================================================
CREATE VIEW blood_group_stock AS
SELECT
    blood_group,
    COUNT(*) AS registered_donors,
    COUNT(*) FILTER (WHERE approved = TRUE) AS approved_donors,
    COUNT(*) FILTER (WHERE verification_status = 'approved') AS verified_donors
FROM users
WHERE role = 'donor'
GROUP BY blood_group
ORDER BY blood_group;
