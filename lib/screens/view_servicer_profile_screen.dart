import 'package:flutter/material.dart';
import '../models/servicer.dart';
import '../text_styles.dart';

class ViewServicerProfileScreen extends StatelessWidget {
  final Servicer servicer;
  final String username;
  final String countryId;
  final String cityId;
  final String locationId;

  const ViewServicerProfileScreen({
    super.key,
    required this.servicer,
    required this.username,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil servisera'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (servicer.profileImageUrl.isNotEmpty)
                Center(
                  child: Image.network(servicer.profileImageUrl, height: 200),
                ),
              const SizedBox(height: 20),
              Text(
                'Naziv tvrtke: ${servicer.companyName}',
                style: TextStyles.headline6,
              ),
              const SizedBox(height: 10),
              Text(
                'Adresa: ${servicer.companyAddress}',
                style: TextStyles.bodyText1,
              ),
              const SizedBox(height: 10),
              Text(
                'Telefon: ${servicer.companyPhone}',
                style: TextStyles.bodyText1,
              ),
              const SizedBox(height: 10),
              Text(
                'Email: ${servicer.companyEmail}',
                style: TextStyles.bodyText1,
              ),
              const SizedBox(height: 10),
              Text(
                'Vrsta usluge: ${_getServiceTypeName(servicer.serviceType)}',
                style: TextStyles.bodyText1,
              ),
              const SizedBox(height: 10),
              Text(
                'Opis: ${servicer.description}',
                style: TextStyles.bodyText1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getServiceTypeName(String serviceType) {
    switch (serviceType) {
      case '001':
        return 'Vodoinstalater';
      case '002':
        return 'Elektroinstalater';
      case '003':
        return 'Suhi radovi';
      default:
        return 'Nepoznato';
    }
  }
}
