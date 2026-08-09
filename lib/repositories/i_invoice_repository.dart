/// Abstract repository interface for invoice operations.

import '../models/invoice_model.dart';

abstract class IInvoiceRepository {
  /// Generate an invoice after payment
  Future<String> createInvoice(InvoiceModel invoice);

  /// Get invoice by ID
  Future<InvoiceModel?> getInvoiceById(String invoiceId);

  /// Get invoices for an organization
  Future<List<InvoiceModel>> getInvoicesForOrg(String orgId);

  /// Get all invoices (super admin)
  Future<List<InvoiceModel>> getAllInvoices();

  /// Get invoice by payment ID
  Future<InvoiceModel?> getInvoiceByPaymentId(String paymentId);

  /// Generate next invoice number (e.g., INV-2024-0001)
  Future<String> generateInvoiceNumber();
}
