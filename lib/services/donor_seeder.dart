import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Seeds 295 Pakistani donors to Firestore 'users' collection.
/// Call from any button/action. Safe to run multiple times (generates unique emails).
class DonorSeeder {
  static final Random _random = Random();

  static const List<String> _firstNamesMale = [
    "Muhammad", "Ahmed", "Ali", "Hassan", "Husain", "Usman", "Omar", "Bilal",
    "Hamza", "Ibrahim", "Zain", "Rayan", "Saad", "Abdullah", "Farhan", "Imran",
    "Kamran", "Naveed", "Rashid", "Shahid", "Tariq", "Yasir", "Asif", "Adnan",
    "Faisal", "Junaid", "Kashif", "Nasir", "Qasim", "Salman", "Waqas", "Zubair",
    "Arslan", "Danish", "Faizan", "Hammad", "Irfan", "Khalid", "Noman", "Rizwan",
    "Sohail", "Tanveer", "Umer", "Waleed", "Adeel", "Babar", "Daniyal", "Ehsan",
    "Fahad", "Ghulam", "Haider", "Jawad", "Mansoor", "Nabeel", "Owais", "Raheel",
    "Sajid", "Talha", "Wasim", "Zahid", "Akram", "Basit", "Faraz", "Haroon",
    "Ismail", "Jameel", "Majid", "Nadeem", "Parvez", "Qadeer", "Rafay", "Sarmad",
    "Tahir", "Umair", "Wajid", "Younis", "Zafar", "Amir", "Arif", "Atif",
    "Azhar", "Fawad", "Habib", "Ijaz", "Jamal", "Latif", "Moiz", "Musa",
    "Naeem", "Raza", "Saqib", "Shayan", "Sufyan", "Taha", "Wahaj", "Yahya",
    "Zeeshan", "Abubakar", "Anas", "Ayaan", "Hadi", "Mikael", "Rehan", "Shoaib",
  ];

  static const List<String> _firstNamesFemale = [
    "Fatima", "Ayesha", "Zainab", "Hira", "Sana", "Maryam", "Noor", "Sara",
    "Amina", "Khadija", "Bismah", "Mehwish", "Sadia", "Nadia", "Rabia", "Saima",
    "Farah", "Kiran", "Nida", "Rukhsana", "Shazia", "Tahira", "Uzma", "Yasmin",
    "Areeba", "Bushra", "Faryal", "Ghazala", "Huma", "Iram", "Komal", "Lubna",
    "Mahnoor", "Noreen", "Palwasha", "Qurat", "Riffat", "Samina", "Tania", "Warda",
    "Zara", "Alishba", "Benish", "Dua", "Eman", "Fiza", "Gul", "Hania",
    "Inaya", "Javeria", "Kinza", "Laiba", "Marium", "Naheed", "Parveen", "Rimsha",
  ];

  static const List<String> _lastNames = [
    "Khan", "Ahmed", "Malik", "Sheikh", "Butt", "Chaudhry", "Raja", "Shah",
    "Ali", "Hussain", "Qureshi", "Siddiqui", "Ansari", "Bhatti", "Cheema",
    "Dar", "Gondal", "Hashmi", "Iqbal", "Janjua", "Kayani", "Lodhi", "Mehmood",
    "Naqvi", "Paracha", "Rana", "Sethi", "Tareen", "Wattoo", "Abbasi", "Awan",
    "Bajwa", "Durrani", "Gill", "Hayat", "Jatoi", "Khokhar", "Leghari", "Mirza",
    "Niazi", "Pirzada", "Rind", "Syed", "Talpur", "Wazir", "Zaman", "Akhtar",
    "Bari", "Chishti", "Farooqi", "Ghani", "Hashim", "Jahangir", "Kamal", "Khalid",
    "Mughal", "Nasir", "Pasha", "Rashid", "Sultan", "Tufail", "Usmani", "Wahab",
    "Yousaf", "Zia", "Akbar", "Amin", "Aslam", "Aziz", "Chandio", "Dawar",
    "Ejaz", "Feroz", "Gulzar", "Hameed", "Imtiaz", "Jamil", "Karim", "Latif",
    "Mahmood", "Nisar", "Qadir", "Rafiq", "Sabir", "Tariq", "Waseem", "Zahid",
  ];

  static const List<String> _cities = [
    "Karachi", "Lahore", "Faisalabad", "Rawalpindi", "Gujranwala", "Peshawar",
    "Multan", "Hyderabad", "Islamabad", "Quetta", "Sialkot", "Sargodha",
    "Bahawalpur", "Sukkur", "Larkana", "Sheikhupura", "Rahim Yar Khan",
    "Jhang", "Dera Ghazi Khan", "Gujrat", "Sahiwal", "Wah Cantonment",
    "Mardan", "Kasur", "Okara", "Mingora", "Nawabshah", "Chiniot",
    "Kotri", "Kāmoke", "Hafizabad", "Sadiqabad", "Mirpur Khas", "Burewala",
    "Kohat", "Khanewal", "Dera Ismail Khan", "Turbat", "Muzaffargarh",
    "Abbottabad", "Mandi Bahauddin", "Shikarpur", "Jacobabad", "Jhelum",
    "Khanpur", "Khairpur", "Khuzdar", "Pakpattan", "Hub", "Daska",
    "Gojra", "Dadu", "Muridke", "Bahawalnagar", "Samundri", "Tando Allahyar",
    "Tando Adam", "Jaranwala", "Chishtian", "Attock", "Vehari", "Kot Abdul Malik",
    "Ferozwala", "Chakwal", "Kamalia", "Umerkot", "Ahmedpur East",
    "Kot Addu", "Wazirabad", "Mansehra", "Layyah", "Mirpur", "Swabi",
    "Charsadda", "Karak", "Mianwali", "Bhakkar", "Haripur", "Nowshera",
    "Thatta", "Badin", "Ghotki", "Kharian", "Hangu", "Lakki Marwat",
    "Bannu", "Dera Allah Yar", "Shahdadkot", "Pishin", "Gwadar", "Ziarat",
  ];

  static const List<String> _designations = [
    "Software Engineer", "Doctor", "Teacher", "Business Owner", "Student",
    "Accountant", "Bank Manager", "Civil Engineer", "Electrician", "Farmer",
    "Government Officer", "Lawyer", "Pharmacist", "Journalist", "Lecturer",
    "Mechanical Engineer", "Nurse", "Police Officer", "Shopkeeper", "Driver",
    "Architect", "Chef", "Dentist", "HR Manager", "IT Consultant",
    "Lab Technician", "Marketing Manager", "Photographer", "Professor", "Sales Manager",
    "Carpenter", "Chartered Accountant", "Data Analyst", "Graphic Designer",
    "Interior Designer", "Mechanic", "Painter", "Pilot", "Plumber", "Real Estate Agent",
  ];

  static const List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  static const List<int> _bloodWeights = [20, 2, 30, 3, 8, 1, 30, 6];
  static const List<String> _genders = ['Male', 'Female'];
  static const List<int> _genderWeights = [70, 30];
  static const List<String> _phonePrefixes = [
    '0300', '0301', '0302', '0303', '0304', '0305', '0306',
    '0307', '0308', '0309', '0310', '0311', '0312', '0313',
    '0314', '0315', '0316', '0317', '0318', '0320', '0321',
    '0322', '0323', '0324', '0325', '0331', '0332', '0333',
    '0334', '0335', '0336', '0337', '0340', '0341', '0342',
    '0343', '0344', '0345', '0346', '0347',
  ];

  static String _weightedPick(List<String> items, List<int> weights) {
    final total = weights.fold(0, (a, b) => a + b);
    int r = _random.nextInt(total);
    for (int i = 0; i < items.length; i++) {
      r -= weights[i];
      if (r < 0) return items[i];
    }
    return items.last;
  }

  static String _generateCnic() {
    return List.generate(13, (_) => _random.nextInt(10).toString()).join();
  }

  static String _generatePhone() {
    final prefix = _phonePrefixes[_random.nextInt(_phonePrefixes.length)];
    final number = List.generate(7, (_) => _random.nextInt(10).toString()).join();
    return '$prefix$number';
  }

  static String _generateEmail(String first, String last, int index) {
    final f = first.toLowerCase().replaceAll(' ', '').replaceAll("'", '');
    final l = last.toLowerCase().replaceAll(' ', '').replaceAll("'", '');
    const domains = ['gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com', 'live.com'];
    final domain = domains[_random.nextInt(domains.length)];
    return '${f}.${l}$index@$domain';
  }

  static Map<String, dynamic> _generateDonor(int index) {
    final gender = _weightedPick(_genders, _genderWeights);
    final firstName = gender == 'Male'
        ? _firstNamesMale[_random.nextInt(_firstNamesMale.length)]
        : _firstNamesFemale[_random.nextInt(_firstNamesFemale.length)];
    final lastName = _lastNames[_random.nextInt(_lastNames.length)];
    final bloodGroup = _weightedPick(_bloodGroups, _bloodWeights);
    final now = DateTime.now();
    final daysAgo = _random.nextInt(180);
    final createdAt = now.subtract(Duration(days: daysAgo));

    return {
      'name': '$firstName $lastName',
      'email': _generateEmail(firstName, lastName, index),
      'contact': _generatePhone(),
      'cnic': _generateCnic(),
      'bloodGroup': bloodGroup,
      'role': 'donor',
      'designation': _designations[_random.nextInt(_designations.length)],
      'age': 18 + _random.nextInt(43),
      'gender': gender,
      'location': '',
      'approved': false,  // Admin must approve before contact is visible
      'verified': false,
      'hasDonated': _random.nextBool(),
      'available': _random.nextDouble() < 0.75,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastDonation': _random.nextDouble() > 0.5
          ? Timestamp.fromDate(createdAt.subtract(Duration(days: 30 + _random.nextInt(335))))
          : null,
    };
  }

  /// Seed [count] donors to Firestore. Default 295.
  /// Shows progress via [onProgress] callback.
  static Future<int> seed({
    int count = 295,
    int batchSize = 50,
    void Function(int done, int total)? onProgress,
  }) async {
    int totalWritten = 0;

    for (int batchStart = 0; batchStart < count; batchStart += batchSize) {
      final batch = FirebaseFirestore.instance.batch();
      final batchEnd = (batchStart + batchSize).clamp(0, count);

      for (int i = batchStart; i < batchEnd; i++) {
        final donor = _generateDonor(i + 1);
        final docRef = FirebaseFirestore.instance.collection('users').doc();
        batch.set(docRef, donor);
      }

      try {
        await batch.commit();
        totalWritten += (batchEnd - batchStart);
        onProgress?.call(totalWritten, count);
      } catch (e) {
        // Fallback: write one-by-one
        for (int i = batchStart; i < batchEnd; i++) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .add(_generateDonor(i + 1));
            totalWritten++;
            onProgress?.call(totalWritten, count);
          } catch (_) {}
        }
      }
    }

    return totalWritten;
  }

  /// Remove all donors where approved == false (seeded donors).
  /// Returns count of deleted donors.
  static Future<int> removeAll({
    void Function(int done, int total)? onProgress,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'donor')
        .where('approved', isEqualTo: false)
        .get();

    final docs = snapshot.docs;
    final total = docs.length;

    if (total == 0) return 0;

    int deleted = 0;
    const batchSize = 50;

    for (int i = 0; i < total; i += batchSize) {
      final batch = FirebaseFirestore.instance.batch();
      final end = (i + batchSize).clamp(0, total);

      for (int j = i; j < end; j++) {
        batch.delete(docs[j].reference);
      }

      try {
        await batch.commit();
        deleted += (end - i);
        onProgress?.call(deleted, total);
      } catch (_) {
        // Fallback: delete one-by-one
        for (int j = i; j < end; j++) {
          try {
            await docs[j].reference.delete();
            deleted++;
            onProgress?.call(deleted, total);
          } catch (_) {}
        }
      }
    }

    return deleted;
  }
}
