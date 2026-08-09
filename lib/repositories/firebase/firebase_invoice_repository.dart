import 'package:cloud_firestore/cloud_firestore.dart';
import '../i_invoice_repository.dart';
import '../../models/invoice_model.dart';

class FirebaseInvoiceRepository implements IInvoiceRepository {
  static const String _collection = 'invoices';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<String> createInvoice(InvoiceModel invoice) async {
    final docRef = await _firestore.collection(_collection).add(invoice.toFirestore());
    return docRef.id;
  }

  @override
  Future<InvoiceModel?> getInvoiceById(String invoiceId) async {
    final doc = await _firestore.collection(_collection).doc(invoiceId).get();
    if (!doc.exists) return null;
    return InvoiceModel.fromFirestore(doc.id, doc.data() ?? {});
  }

  @override
  Future<List<InvoiceModel>> getInvoicesForOrg(String orgId) async {
    final snap = await _firestore
        .collection(_collection)
        .where('organizationId', isEqualTo: orgId)
        .orderBy('invoiceDate', descending: true)
        .get();
    return snap.docs.map((d) => InvoiceModel.fromFirestore(d.id, d.data())).toList();
  }

  @override
  Future<List<InvoiceModel>> getAllInvoices() async {
    final snap = await _firestore
        .collection(_collection)
        .orderBy('invoiceDate', descending: true)
        .get();
    return snap.docs.map((d) => InvoiceModel.fromFirestore(d.id, d.data())).toList();
  }

  @override
  Future<InvoiceModel?> getInvoiceByPaymentId(String paymentId) async {
    final snap = await _firestore
        .collection(_collection)
        .where('paymentId', isEqualTo: paymentId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return InvoiceModel.fromFirestore(snap.docs.first.id, snap.docs.first.data());
  }

  @override
  Future<String> generateInvoiceNumber() async {
    final now = DateTime.now();
    final year = now.year;
    final snap = await _firestore
        .collection(_collection)
        .where('invoiceNumber', isGreaterThanOrEqualTo: 'INV-$year-')
        .where('invoiceNumber', isLessThan: 'INV-${year + 1}-')
        .orderBy('invoiceNumber', descending: true)
        .limit(1)
        .get();

    int nextNum = 1;
    if (snap.docs.isNotEmpty) {
      final lastNum = snap.docs.first.data()['invoiceNumber']?.toString() ?? '';
      final parts = lastNum.split('-');
      if (parts.length == 3) {
        nextNum = (int.tryParse(parts[2]) ?? 0) + 1;
      }
    }
    return 'INV-$year-${nextNum.toString().padLeft(4, '0')}';
  }
}
