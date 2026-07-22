-- ============================================================================
-- Blood Bridge - Standalone PostgreSQL / MySQL Schema
-- ============================================================================
-- Use this if you're setting up your own PostgreSQL or MySQL server
-- (not using Supabase). This is the same schema without Supabase-specific
-- RLS policies and auth.users references.

-- ============================================================================
-- POSTGRESQL VERSION
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,           -- bcrypt hash
    contact VARCHAR(50),
    blood_group VARCHAR(5),
    role VARCHAR(20) NOT NULL DEFAULT 'user',
    location VARCHAR(500),
    designation VARCHAR(255),
    age INTEGER CHECK (age >= 18 AND age <= 65),
    gender VARCHAR(20),
    cnic VARCHAR(20),
    approved BOOLEAN DEFAULT FALSE,
    is_donor BOOLEAN DEFAULT FALSE,
    first_donation_approved BOOLEAN,
    photo_data TEXT,
    verification_document_data TEXT,
    verification_status VARCHAR(20) DEFAULT 'not_uploaded',
    refresh_token VARCHAR(500),
    cooldown_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_blood_group ON users(blood_group);
CREATE INDEX idx_users_email ON users(email);

CREATE TABLE blood_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type VARCHAR(30) NOT NULL DEFAULT 'donor_request',
    donor_email VARCHAR(255),
    donor_name VARCHAR(255),
    donor_id UUID REFERENCES users(id),
    requester_email VARCHAR(255),
    requester_name VARCHAR(255),
    recipient_email VARCHAR(255),
    recipient_name VARCHAR(255),
    blood_group VARCHAR(5),
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    message TEXT,
    location VARCHAR(500),
    urgency VARCHAR(20) DEFAULT 'normal',
    units INTEGER DEFAULT 1,
    is_emergency BOOLEAN DEFAULT FALSE,
    response_message TEXT,
    requested_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    responded_at TIMESTAMPTZ
);

CREATE INDEX idx_blood_requests_status ON blood_requests(status);
CREATE INDEX idx_blood_requests_donor_email ON blood_requests(donor_email);

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chat_id VARCHAR(255) NOT NULL,
    sender_id UUID NOT NULL REFERENCES users(id),
    sender_name VARCHAR(255),
    receiver_id UUID NOT NULL REFERENCES users(id),
    receiver_name VARCHAR(255),
    message TEXT NOT NULL,
    read BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_messages_chat_id ON messages(chat_id);

CREATE TABLE broadcasts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message TEXT NOT NULL,
    target_audience VARCHAR(20) NOT NULL DEFAULT 'all',
    sender_id UUID NOT NULL REFERENCES users(id),
    sender_name VARCHAR(255),
    sent_at TIMESTAMPTZ DEFAULT NOW()
);

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
    is_reminder BOOLEAN DEFAULT FALSE,
    reminder_date TIMESTAMPTZ,
    reminder_sent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- MYSQL VERSION (uncomment and use for MySQL)
-- ============================================================================
/*
CREATE TABLE users (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    contact VARCHAR(50),
    blood_group VARCHAR(5),
    role VARCHAR(20) NOT NULL DEFAULT 'user',
    location VARCHAR(500),
    designation VARCHAR(255),
    age INT CHECK (age >= 18 AND age <= 65),
    gender VARCHAR(20),
    cnic VARCHAR(20),
    approved TINYINT(1) DEFAULT 0,
    is_donor TINYINT(1) DEFAULT 0,
    first_donation_approved TINYINT(1) DEFAULT NULL,
    photo_data LONGTEXT,
    verification_document_data LONGTEXT,
    verification_status VARCHAR(20) DEFAULT 'not_uploaded',
    refresh_token VARCHAR(500),
    cooldown_until DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_role (role),
    INDEX idx_blood_group (blood_group),
    INDEX idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE blood_requests (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    type VARCHAR(30) NOT NULL DEFAULT 'donor_request',
    donor_email VARCHAR(255),
    donor_name VARCHAR(255),
    donor_id CHAR(36),
    requester_email VARCHAR(255),
    requester_name VARCHAR(255),
    recipient_email VARCHAR(255),
    recipient_name VARCHAR(255),
    blood_group VARCHAR(5),
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    message TEXT,
    location VARCHAR(500),
    urgency VARCHAR(20) DEFAULT 'normal',
    units INT DEFAULT 1,
    is_emergency TINYINT(1) DEFAULT 0,
    response_message TEXT,
    requested_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    responded_at DATETIME,
    INDEX idx_status (status),
    INDEX idx_donor_email (donor_email),
    FOREIGN KEY (donor_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE messages (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    chat_id VARCHAR(255) NOT NULL,
    sender_id CHAR(36) NOT NULL,
    sender_name VARCHAR(255),
    receiver_id CHAR(36) NOT NULL,
    receiver_name VARCHAR(255),
    message TEXT NOT NULL,
    `read` TINYINT(1) DEFAULT 0,
    sent_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_chat_id (chat_id),
    FOREIGN KEY (sender_id) REFERENCES users(id),
    FOREIGN KEY (receiver_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE broadcasts (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    message TEXT NOT NULL,
    target_audience VARCHAR(20) NOT NULL DEFAULT 'all',
    sender_id CHAR(36) NOT NULL,
    sender_name VARCHAR(255),
    sent_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sender_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE donations (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    donor_id CHAR(36) NOT NULL,
    donor_name VARCHAR(255),
    donor_email VARCHAR(255),
    recipient_id CHAR(36),
    recipient_name VARCHAR(255),
    blood_group VARCHAR(5),
    units INT DEFAULT 1,
    donation_date DATETIME,
    location VARCHAR(500),
    notes TEXT,
    is_reminder TINYINT(1) DEFAULT 0,
    reminder_date DATETIME,
    reminder_sent TINYINT(1) DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (donor_id) REFERENCES users(id),
    FOREIGN KEY (recipient_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
*/
