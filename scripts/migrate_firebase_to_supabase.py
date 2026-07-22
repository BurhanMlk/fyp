"""
Blood Bridge - Firebase Firestore → Supabase PostgreSQL Migration Script
=======================================================================

This script migrates ALL existing data from Firebase Firestore to Supabase PostgreSQL.

PREREQUISITES:
1. Install Python packages:
   pip install firebase-admin supabase

2. Get your Firebase service account key:
   - Go to Firebase Console → Project Settings → Service Accounts
   - Click "Generate New Private Key" → download the JSON file
   - Save it as firebase-service-account.json in this scripts/ folder

3. Get your Supabase service_role key:
   - Go to Supabase Dashboard → Settings → API Keys
   - Copy the "secret key" (starts with sb_secret_...)
   - Paste it below in SUPABASE_SERVICE_KEY

USAGE:
   python scripts/migrate_firebase_to_supabase.py
"""

import json
import sys
import os
from datetime import datetime, date, time

# ============================================================
# CONFIGURATION - UPDATE THESE VALUES
# ============================================================

# Your Supabase URL (same as in supabase_config.dart)
SUPABASE_URL = "https://xhrmntouhykreebonsio.supabase.co"

# Your Supabase SERVICE ROLE key (NOT the publishable key!)
# Get this from: Supabase Dashboard → Settings → API Keys → secret key
SUPABASE_SERVICE_KEY = "YOUR_SUPABASE_SERVICE_ROLE_KEY"  # Replace with your key from Supabase Dashboard → Settings → API

# Path to your Firebase service account JSON file
FIREBASE_SA_PATH = os.path.join(os.path.dirname(__file__), "firebase-service-account.json")

# ============================================================
# FIELD MAPPING: Firestore → PostgreSQL (snake_case)
# ============================================================

USER_FIELD_MAP = {
    "name": "name", "email": "email", "contact": "contact",
    "bloodGroup": "blood_group", "role": "role", "location": "location",
    "designation": "designation", "age": "age", "gender": "gender",
    "cnic": "cnic", "approved": "approved", "isDonor": "is_donor",
    "firstDonationApproved": "first_donation_approved",
    "photoData": "photo_data",
    "verificationDocumentData": "verification_document_data",
    "verificationStatus": "verification_status",
    "cooldownUntil": "cooldown_until",
    "createdAt": "created_at", "updatedAt": "updated_at",
}

REQUEST_FIELD_MAP = {
    "type": "type", "donorEmail": "donor_email", "donorName": "donor_name",
    "donorId": "donor_id", "requesterEmail": "requester_email",
    "requesterName": "requester_name", "recipientEmail": "recipient_email",
    "recipientName": "recipient_name", "bloodGroup": "blood_group",
    "status": "status", "message": "message", "location": "location",
    "urgency": "urgency", "units": "units", "isEmergency": "is_emergency",
    "responseMessage": "response_message",
    "requestedAt": "requested_at", "updatedAt": "updated_at",
    "respondedAt": "responded_at",
}

def to_json_safe(val):
    """Recursively convert Firestore types to JSON-safe Python types."""
    if val is None:
        return None
    if isinstance(val, (str, int, float, bool)):
        return val
    if isinstance(val, (datetime, date)):
        return val.isoformat()
    # Firestore DatetimeWithNanoseconds / google.cloud.firestore types
    if hasattr(val, 'isoformat'):
        try:
            return val.isoformat()
        except:
            pass
    # Firestore GeoPoint
    if hasattr(val, 'latitude') and hasattr(val, 'longitude'):
        return {"latitude": val.latitude, "longitude": val.longitude}
    # Firestore DocumentReference
    if hasattr(val, 'path'):
        return str(val.path)
    if isinstance(val, dict):
        return {k: to_json_safe(v) for k, v in val.items()}
    if isinstance(val, list):
        return [to_json_safe(x) for x in val]
    # Fallback: try converting to string
    return str(val)


def transform_doc(firestore_doc, field_map):
    """Convert Firestore camelCase fields to PostgreSQL snake_case."""
    result = {"id": firestore_doc.get("id", "")}
    for firestore_key, pg_key in field_map.items():
        if firestore_key in firestore_doc:
            value = firestore_doc[firestore_key]
            result[pg_key] = to_json_safe(value)
    return result


def main():
    print("=" * 60)
    print("Blood Bridge - Firebase → PostgreSQL Migration")
    print("=" * 60)

    # --- Check prerequisites ---
    if SUPABASE_SERVICE_KEY == "YOUR_SUPABASE_SERVICE_ROLE_KEY":
        print("\n❌ ERROR: Please set SUPABASE_SERVICE_KEY in this script!")
        print("   Get it from: Supabase Dashboard → Settings → API Keys → secret key")
        sys.exit(1)

    if not os.path.exists(FIREBASE_SA_PATH):
        print(f"\n❌ ERROR: Firebase service account file not found at:")
        print(f"   {FIREBASE_SA_PATH}")
        print("\n   To get this file:")
        print("   1. Go to Firebase Console → Project Settings → Service Accounts")
        print("   2. Click 'Generate New Private Key'")
        print("   3. Save the JSON file as 'firebase-service-account.json'")
        print("      in the scripts/ folder")
        sys.exit(1)

    # --- Initialize Firebase Admin ---
    print("\n🔥 Initializing Firebase...")
    import firebase_admin
    from firebase_admin import credentials, firestore

    cred = credentials.Certificate(FIREBASE_SA_PATH)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("   ✅ Firebase connected")

    # --- Initialize Supabase ---
    print("\n🐘 Initializing Supabase...")
    from supabase import create_client
    supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    print("   ✅ Supabase connected")

    # --- MIGRATE USERS ---
    print("\n📦 Migrating users collection...")
    users_ref = db.collection("users")
    users_docs = users_ref.stream()
    
    user_count = 0
    for doc in users_docs:
        data = doc.to_dict()
        data["id"] = doc.id
        pg_data = transform_doc(data, USER_FIELD_MAP)
        
        try:
            supabase.table("users").upsert(pg_data, on_conflict="id").execute()
            user_count += 1
            print(f"   ✅ {data.get('name', 'Unknown')} ({data.get('email', '')})")
        except Exception as e:
            print(f"   ❌ Error migrating user {doc.id}: {e}")

    print(f"   📊 Migrated {user_count} users")

    # --- MIGRATE BLOOD REQUESTS ---
    print("\n📦 Migrating donor_requests → blood_requests...")
    requests_ref = db.collection("donor_requests")
    requests_docs = requests_ref.stream()
    
    request_count = 0
    for doc in requests_docs:
        data = doc.to_dict()
        data["id"] = doc.id
        pg_data = transform_doc(data, REQUEST_FIELD_MAP)
        
        try:
            supabase.table("blood_requests").upsert(pg_data, on_conflict="id").execute()
            request_count += 1
            print(f"   ✅ Request: {data.get('type', 'unknown')} - {data.get('status', '?')}")
        except Exception as e:
            print(f"   ❌ Error migrating request {doc.id}: {e}")

    print(f"   📊 Migrated {request_count} blood requests")

    # --- MIGRATE MESSAGES (if they exist) ---
    print("\n📦 Migrating messages...")
    try:
        messages_ref = db.collection("messages")
        messages_docs = messages_ref.stream()
        msg_count = 0
        for doc in messages_docs:
            data = doc.to_dict()
            pg_data = {
                "id": doc.id,
                "chat_id": data.get("chatId", ""),
                "sender_id": data.get("senderId", ""),
                "sender_name": data.get("senderName", ""),
                "receiver_id": data.get("receiverId", ""),
                "receiver_name": data.get("receiverName", ""),
                "message": data.get("message", ""),
                "read": data.get("read", False),
                "sent_at": data.get("sentAt", data.get("createdAt", "")) if isinstance(data.get("sentAt"), str) else datetime.now().isoformat(),
            }
            try:
                supabase.table("messages").upsert(pg_data, on_conflict="id").execute()
                msg_count += 1
            except Exception as e:
                print(f"   ❌ Error: {e}")
        print(f"   📊 Migrated {msg_count} messages")
    except Exception as e:
        print(f"   ⚠️ Messages collection may not exist: {e}")

    # --- MIGRATE BROADCASTS ---
    print("\n📦 Migrating broadcasts...")
    try:
        broadcasts_ref = db.collection("broadcasts")
        broadcasts_docs = broadcasts_ref.stream()
        bcast_count = 0
        for doc in broadcasts_docs:
            data = doc.to_dict()
            pg_data = {
                "id": doc.id,
                "message": data.get("message", ""),
                "target_audience": data.get("targetAudience", data.get("target", "all")),
                "sender_id": data.get("senderId", ""),
                "sender_name": data.get("senderName", ""),
                "sent_at": data.get("sentAt", data.get("createdAt", "")) if isinstance(data.get("sentAt"), str) else datetime.now().isoformat(),
            }
            try:
                supabase.table("broadcasts").upsert(pg_data, on_conflict="id").execute()
                bcast_count += 1
            except Exception as e:
                print(f"   ❌ Error: {e}")
        print(f"   📊 Migrated {bcast_count} broadcasts")
    except Exception as e:
        print(f"   ⚠️ Broadcasts collection may not exist: {e}")

    # --- SUMMARY ---
    print("\n" + "=" * 60)
    print("🎉 MIGRATION COMPLETE!")
    print(f"   Users:          {user_count}")
    print(f"   Blood Requests: {request_count}")
    print(f"   Messages:       {msg_count if 'msg_count' in dir() else 'N/A'}")
    print(f"   Broadcasts:     {bcast_count if 'bcast_count' in dir() else 'N/A'}")
    print("=" * 60)
    print("\n✅ Verify in Supabase → Table Editor")
    print("   https://supabase.com/dashboard/project/fmqtyvncopcwidefkdjk")


if __name__ == "__main__":
    main()
