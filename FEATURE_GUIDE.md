# Document Verification System - Feature Guide

## Quick Start Guide

### For Recipients

#### 📤 How to Upload Documents

1. **Open Your Profile**
   - Tap Profile icon in bottom navigation
   - Scroll down to "Personal Details" section

2. **Find Document Verification Card**
   - Look for blue "Document Verification" card with verification icon
   - Shows current status (⏳ Pending or ✓ Verified)

3. **Click "Manage Documents"**
   - Opens Document Upload Screen
   - Shows your previously uploaded documents

4. **Upload New Document**
   - Click "Choose & Upload Document" button
   - Select document type from dropdown:
     - 🪪 CNIC / National ID
     - 🛂 Passport
     - 📋 Medical Report
     - 📄 Other Document
   - Choose file from device (PDF, JPG, or PNG)
   - System uploads and shows success message

5. **Track Status**
   - Go back to "Manage Documents" anytime
   - See ⏳ Pending for documents under review
   - See ✓ Verified with verification date when approved

#### ✅ What You'll See After Verification

1. **In Profile**:
   - Blood group now shows in Personal Details section
   - All personal details display blue ✓ Verified badges
   - Document card shows "Documents Verified ✓"

2. **Notifications**:
   - Receive notification: "Documents Verified ✓"
   - Message: "Your documents have been verified and approved by the admin"

---

### For Admin

#### 🔍 How to Review Documents

1. **Access Document Verification**
   
   **Option A - From Drawer:**
   - Tap menu icon (hamburger)
   - Scroll to find "Document Verification"
   - Tap to open

   **Option B - From Dashboard:**
   - Dashboard opens automatically
   - Find "Document Verification" card in Quick Access grid
   - Click to open

2. **View Statistics**
   - See "Pending" count (orange badge) - documents waiting for review
   - See "Verified" count (green badge) - previously approved documents

3. **Filter Documents**
   - Tabs at top: Pending | Verified | All
   - Click to switch views

4. **Review a Document**
   - Click any document card to open details
   - See user name, email, document type
   - Shows upload date
   - Shows status: ⏳ PENDING or ✓ VERIFIED

5. **Make Decision**
   
   **To Approve:**
   - Click green "✓ Approve" button
   - Confirm in dialog box
   - System sends notification to user
   - Status updates to "✓ VERIFIED"
   - Verification date recorded

   **To Reject:**
   - Click red "✗ Reject" button
   - Confirm in dialog box
   - Document marked as rejected
   - User can resubmit new document

6. **Go Back**
   - Click "← Back to List"
   - Returns to document list
   - Refreshed list shows updated statuses

---

## Profile Changes Explained

### Blood Group Location

**Before:**
```
┌─────────────────────────┐
│      [Profile Photo]    │
│         DONOR           │
│      B+ • Role          │  ← Blood group in header
├─────────────────────────┤
│   Personal Details      │
│   Age: 28 years        │
│   Gender: Male         │
```

**After:**
```
┌─────────────────────────┐
│      [Default Avatar]   │
│         DONOR           │  (without blood group)
├─────────────────────────┤
│   Personal Details      │
│   🩸 Blood Group: B+ ✓ │  ← Now here with badge!
│   🎂 Age: 28 years ✓   │
│   👥 Gender: Male ✓    │
```

### Verification Badges

Each personal detail now shows:
- **Icon**: Type of information
- **Label**: Name of field
- **Blue ✓**: Indicates this detail has been verified
- **Value**: Your information

Example:
```
🩸 Blood Group ✓        (blue checkmark badge)
   B+                   (your blood group)
```

---

## Document Types Explained

### 🪪 CNIC / National ID
- Pakistani Computerized National ID Card
- Format: XXXXX-XXXXXXX-X (13 digits)
- Used for primary identity verification
- Preferred document type

### 🛂 Passport
- International travel document
- Issued by government authority
- Valid for identity verification
- Accepted globally

### 📋 Medical Report
- Health assessment document
- Useful for blood donation eligibility
- Can include blood type confirmation
- Recent reports preferred

### 📄 Other Document
- Government ID from other countries
- Employer ID with photo
- Student ID with security features
- Any official ID document

---

## Status Indicators

### Document Upload Screen

| Status | Icon | Color | Meaning |
|--------|------|-------|---------|
| ⏳ Pending | Clock | Orange | Waiting for admin review |
| ✓ Verified | Check | Green | Approved by admin |
| Uploaded At | Calendar | Gray | Date document was uploaded |
| Verified on | Verified badge | Blue | Date admin approved |

### Admin Review Panel

| Status | Background | Meaning |
|--------|------------|---------|
| ⏳ PENDING | Orange | Needs your review |
| ✓ VERIFIED | Green | Already approved |
| ✗ REJECTED | Red | Was rejected |

---

## Document Upload Requirements

### File Format
- ✅ **Supported**: PDF, JPG, PNG
- ❌ **Not Supported**: WORD, EXCEL, GIF, BMP
- 📏 **Max Size**: 10 MB per file
- 🖼️ **Quality**: Clear, readable image

### Content Requirements
- ✅ Document should be clear and legible
- ✅ Face visible on ID documents
- ✅ All security features should be visible
- ✅ Recent document (within 6 months)
- ❌ Blurry or damaged documents will be rejected

### Tips for Better Results
1. Use good lighting
2. Hold document flat
3. Include all corners in frame
4. Avoid glare or reflections
5. Make sure text is readable
6. Take photo from directly above

---

## Troubleshooting

### "File Not Selected"
- Click button again
- Grant file access permission
- Try different file

### "Upload Failed"
- Check internet connection
- Verify file size (less than 10 MB)
- Try PDF instead of image
- Refresh and try again

### "Document Not Appearing"
- Refresh the screen
- Log out and log back in
- Check your email for notifications
- Contact admin if still not visible

### "Approval Taking Too Long"
- Admins review during business hours
- Usually approved within 24-48 hours
- Check notification settings
- Check document requirements again

---

## Admin Workflow

### Quick Process

1. **Morning**: Check dashboard → See pending count
2. **Open Module**: "Document Verification" in drawer
3. **Review**: Click each pending document
4. **Decide**: Click Approve or Reject
5. **Confirm**: Click Yes in confirmation
6. **Complete**: System notifies user automatically
7. **Track**: Switch to "Verified" tab to see history

### Batch Processing Example

```
Monday Morning:
├─ Open Document Verification
├─ See: 5 pending, 23 verified
├─ Review document #1 → Approve
├─ Review document #2 → Approve
├─ Review document #3 → Reject
├─ Review document #4 → Approve
├─ Review document #5 → Approve
└─ Refresh: Now shows 0 pending, 28 verified ✓

Users notified automatically!
```

---

## Features Summary

### For Recipients ✨
- ✅ Upload identification documents anytime
- ✅ Choose from 4 document types
- ✅ See upload status in real-time
- ✅ Receive approval notifications
- ✅ See verification date when approved
- ✅ Resubmit if rejected
- ✅ View verification badges on profile

### For Admin 🔐
- ✅ View all pending documents
- ✅ Filter by status (pending/verified/all)
- ✅ See user information
- ✅ Document type and upload date
- ✅ Approve or reject with confirmation
- ✅ Automatic user notifications
- ✅ Verification history and dates
- ✅ Statistics dashboard

### System Features ⚙️
- ✅ Two-mode support (Firebase & Demo)
- ✅ Secure file handling
- ✅ Timestamp tracking
- ✅ Audit trail
- ✅ Notification system
- ✅ Status indicators
- ✅ Filter options
- ✅ Responsive design

---

## Important Notes

⚠️ **Security**
- Only recipients can upload
- Only admins can verify
- Files are encrypted in storage
- Access is role-based

📱 **Supported Platforms**
- Android ✅
- iOS ✅
- Web (Limited file picker)

🔄 **Synchronization**
- Changes appear in real-time
- No manual refresh needed
- Notifications sent immediately
- Status updates instantly

---

## Getting Help

### Common Questions

**Q: How long does verification take?**
A: Usually 24-48 hours during business days

**Q: Can I upload multiple documents?**
A: Yes! Upload as many as needed, each type can be resubmitted

**Q: What if my document is rejected?**
A: Upload a new one with better quality/legibility

**Q: Will I get notified?**
A: Yes! You'll receive notification when verified

**Q: What documents should I upload?**
A: Preferred: CNIC. Also accepted: Passport, Medical Report

**Q: Can I delete uploaded documents?**
A: Contact admin if you need to remove a document

---

## Pro Tips 💡

1. **Upload Early**: Don't wait until last minute
2. **Good Quality**: Clear documents = faster approval
3. **Read Requirements**: Check what document types are accepted
4. **Keep Copy**: Save a copy for yourself
5. **Check Status**: Regularly check your documents section
6. **Enable Notifications**: Turn on push notifications to get alerts

---

## Keyboard Shortcuts (Admin)

| Action | Shortcut |
|--------|----------|
| Toggle Menu | ESC (on web) |
| Search Documents | Cmd+F / Ctrl+F |
| Refresh | F5 / Cmd+R |
| Next Document | Tab |
| Approve | Enter (after focus) |

---

End of Feature Guide ✅
Last Updated: June 24, 2026
