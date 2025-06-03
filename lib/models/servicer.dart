import 'package:cloud_firestore/cloud_firestore.dart';

class Servicer {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String personalId;
  final String phone;
  final String mobile;
  final String email;
  final String companyName;
  final String companyPhone;
  final String companyEmail;
  final String companyOib;
  final String companyAddress;
  final String companyMaticniBroj;
  final String nkd;
  final String owner;
  final String website;
  final String serviceType;
  final String profileImageUrl;
  final String personalIdUrl;
  final String additionalDocumentUrl;
  final String workshopPhotoUrl;
  final String username;
  final String workingCountry; // Novo polje
  final String workingCity; // Novo polje
  final String address; // Dodano
  final String description; // Dodano
  final String imageUrl; // Dodano
  final DateTime? createdAt;

  Servicer({
    required this.id, // dodan ID
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.personalId,
    required this.phone,
    required this.mobile,
    required this.email,
    required this.companyName,
    required this.companyPhone,
    required this.companyEmail,
    required this.companyOib,
    required this.companyAddress,
    required this.companyMaticniBroj,
    required this.nkd,
    required this.owner,
    required this.website,
    required this.serviceType,
    required this.profileImageUrl,
    required this.personalIdUrl,
    required this.additionalDocumentUrl,
    required this.workshopPhotoUrl,
    required this.username,
    required this.workingCountry, // Novo polje
    required this.workingCity, // Novo polje
    required this.address, // Dodano
    required this.description, // Dodano
    required this.imageUrl, // Dodano
    this.createdAt,
  });

  factory Servicer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Servicer(
      id: doc.id, // postavite ID dokumenta kao id za Servicer
      userId: data['userId'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      personalId: data['personalId'] ?? '',
      phone: data['phone'] ?? '',
      mobile: data['mobile'] ?? '',
      email: data['email'] ?? '',
      companyName: data['companyName'] ?? '',
      companyPhone: data['companyPhone'] ?? '',
      companyEmail: data['companyEmail'] ?? '',
      companyOib: data['companyOib'] ?? '',
      companyAddress: data['companyAddress'] ?? '',
      companyMaticniBroj: data['companyMaticniBroj'] ?? '',
      nkd: data['nkd'] ?? '',
      owner: data['owner'] ?? '',
      website: data['website'] ?? '',
      serviceType: data['serviceType'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      personalIdUrl: data['personalIdUrl'] ?? '',
      additionalDocumentUrl: data['additionalDocumentUrl'] ?? '',
      workshopPhotoUrl: data['workshopPhotoUrl'] ?? '',
      username: data['username'] ?? '',
      workingCountry: data['workingCountry'] ?? '',
      workingCity: data['workingCity'] ?? '',
      address:
          data['companyAddress'] ?? '', // Koristimo companyAddress kao address
      description: data['description'] ?? '', // Koristimo description
      imageUrl: data['profileImageUrl'] ??
          '', // Koristimo profileImageUrl kao imageUrl
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'firstName': firstName,
      'lastName': lastName,
      'personalId': personalId,
      'phone': phone,
      'mobile': mobile,
      'email': email,
      'companyName': companyName,
      'companyPhone': companyPhone,
      'companyEmail': companyEmail,
      'companyOib': companyOib,
      'companyAddress': companyAddress,
      'companyMaticniBroj': companyMaticniBroj,
      'nkd': nkd,
      'owner': owner,
      'website': website,
      'serviceType': serviceType,
      'profileImageUrl': profileImageUrl,
      'personalIdUrl': personalIdUrl,
      'additionalDocumentUrl': additionalDocumentUrl,
      'workshopPhotoUrl': workshopPhotoUrl,
      'username': username,
      'workingCountry': workingCountry,
      'workingCity': workingCity,
      'address': address,
      'description': description,
      'imageUrl': imageUrl,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }
}
