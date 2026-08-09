/// Service Locator / Dependency Injection container for Blood Bridge.
/// Supports dual backend: Firebase (Firestore) and Supabase (PostgreSQL).

import '../repositories/i_auth_repository.dart';
import '../repositories/i_user_repository.dart';
import '../repositories/i_blood_request_repository.dart';
import '../repositories/i_chat_repository.dart';
import '../repositories/i_broadcast_repository.dart';
import '../repositories/i_donation_repository.dart';
import '../repositories/i_storage_repository.dart';
import '../repositories/i_organization_repository.dart';
import '../repositories/i_subscription_plan_repository.dart';
import '../repositories/i_subscription_repository.dart';
import '../repositories/i_payment_repository.dart';
import '../repositories/i_invoice_repository.dart';
import '../repositories/i_blood_inventory_repository.dart';

import '../repositories/firebase/firebase_auth_repository.dart';
import '../repositories/firebase/firebase_user_repository.dart';
import '../repositories/firebase/firebase_blood_request_repository.dart';
import '../repositories/firebase/firebase_chat_repository.dart';
import '../repositories/firebase/firebase_broadcast_repository.dart';
import '../repositories/firebase/firebase_donation_repository.dart';
import '../repositories/firebase/firebase_storage_repository.dart';
import '../repositories/firebase/firebase_organization_repository.dart';
import '../repositories/firebase/firebase_subscription_plan_repository.dart';
import '../repositories/firebase/firebase_subscription_repository.dart';
import '../repositories/firebase/firebase_payment_repository.dart';
import '../repositories/firebase/firebase_invoice_repository.dart';
import '../repositories/firebase/firebase_blood_inventory_repository.dart';

import '../repositories/supabase/supabase_auth_repository.dart';
import '../repositories/supabase/supabase_user_repository.dart';
import '../repositories/supabase/supabase_blood_request_repository.dart';
import '../repositories/supabase/supabase_chat_repository.dart';
import '../repositories/supabase/supabase_broadcast_repository.dart';
import '../repositories/supabase/supabase_donation_repository.dart';
import '../repositories/supabase/supabase_storage_repository.dart';

/// Enum to specify which backend to use.
enum BackendProvider { firebase, supabase }

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  /// Set to [BackendProvider.firebase] to revert to Firebase.
  BackendProvider _provider = BackendProvider.firebase;

  // Repository instances (lazy-initialized)
  IAuthRepository? _authRepo;
  IUserRepository? _userRepo;
  IBloodRequestRepository? _bloodRequestRepo;
  IChatRepository? _chatRepo;
  IBroadcastRepository? _broadcastRepo;
  IDonationRepository? _donationRepo;
  IStorageRepository? _storageRepo;
  IOrganizationRepository? _orgRepo;
  ISubscriptionPlanRepository? _planRepo;
  ISubscriptionRepository? _subscriptionRepo;
  IPaymentRepository? _paymentRepo;
  IInvoiceRepository? _invoiceRepo;
  IBloodInventoryRepository? _bloodInventoryRepo;

  /// Switch the backend provider.
  void setProvider(BackendProvider provider) {
    _provider = provider;
    // Clear all cached instances so they're recreated
    _authRepo = null;
    _userRepo = null;
    _bloodRequestRepo = null;
    _chatRepo = null;
    _broadcastRepo = null;
    _donationRepo = null;
    _storageRepo = null;
    _orgRepo = null;
    _planRepo = null;
    _subscriptionRepo = null;
    _paymentRepo = null;
    _invoiceRepo = null;
    _bloodInventoryRepo = null;
  }

  BackendProvider get currentProvider => _provider;

  // --- Repository Getters ---

  IAuthRepository get auth {
    _authRepo ??= _provider == BackendProvider.supabase
        ? SupabaseAuthRepository()
        : FirebaseAuthRepository();
    return _authRepo!;
  }

  IUserRepository get user {
    _userRepo ??= _provider == BackendProvider.supabase
        ? SupabaseUserRepository()
        : FirebaseUserRepository();
    return _userRepo!;
  }

  IBloodRequestRepository get bloodRequest {
    _bloodRequestRepo ??= _provider == BackendProvider.supabase
        ? SupabaseBloodRequestRepository()
        : FirebaseBloodRequestRepository();
    return _bloodRequestRepo!;
  }

  IChatRepository get chat {
    _chatRepo ??= _provider == BackendProvider.supabase
        ? SupabaseChatRepository()
        : FirebaseChatRepository();
    return _chatRepo!;
  }

  IBroadcastRepository get broadcast {
    _broadcastRepo ??= _provider == BackendProvider.supabase
        ? SupabaseBroadcastRepository()
        : FirebaseBroadcastRepository();
    return _broadcastRepo!;
  }

  IDonationRepository get donation {
    _donationRepo ??= _provider == BackendProvider.supabase
        ? SupabaseDonationRepository()
        : FirebaseDonationRepository();
    return _donationRepo!;
  }

  IStorageRepository get storage {
    _storageRepo ??= _provider == BackendProvider.supabase
        ? SupabaseStorageRepository()
        : FirebaseStorageRepository();
    return _storageRepo!;
  }

  IOrganizationRepository get organization {
    _orgRepo ??= FirebaseOrganizationRepository();
    return _orgRepo!;
  }

  ISubscriptionPlanRepository get subscriptionPlan {
    _planRepo ??= FirebaseSubscriptionPlanRepository();
    return _planRepo!;
  }

  ISubscriptionRepository get subscription {
    _subscriptionRepo ??= FirebaseSubscriptionRepository();
    return _subscriptionRepo!;
  }

  IPaymentRepository get payment {
    _paymentRepo ??= FirebasePaymentRepository();
    return _paymentRepo!;
  }

  IInvoiceRepository get invoice {
    _invoiceRepo ??= FirebaseInvoiceRepository();
    return _invoiceRepo!;
  }

  IBloodInventoryRepository get bloodInventory {
    _bloodInventoryRepo ??= FirebaseBloodInventoryRepository();
    return _bloodInventoryRepo!;
  }
}

/// Convenience getter for accessing the service locator.
ServiceLocator get sl => ServiceLocator();
