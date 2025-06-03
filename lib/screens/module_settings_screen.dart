// lib/screens/module_settings_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';
import 'package:logger/logger.dart';

class ModuleSettingsScreen extends StatefulWidget {
  final String countryId;
  final String cityId;
  final String locationId;

  const ModuleSettingsScreen({
    super.key,
    required this.countryId,
    required this.cityId,
    required this.locationId,
  });

  @override
  _ModuleSettingsScreenState createState() => _ModuleSettingsScreenState();
}

class _ModuleSettingsScreenState extends State<ModuleSettingsScreen> {
  final Logger _logger = Logger();
  final Map<String, bool> _enabledModules = {
    'officialNotices': true,
    'chatRoom': true,
    'quiz': true,
    'bulletinBoard': true,
    'parkingCommunity': true,
    'wiseOwl': true,
    'snowCleaning': true,
    'security': true,
    'alarm': true,
    'noise': true,
    'readings': true,
  };

  @override
  void initState() {
    super.initState();
    _fetchModuleSettings();
  }

  Future<void> _fetchModuleSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final modulesData =
            data?['enabledModules'] as Map<String, dynamic>? ?? {};

        setState(() {
          _enabledModules['officialNotices'] =
              modulesData['officialNotices'] ?? true;
          _enabledModules['chatRoom'] = modulesData['chatRoom'] ?? true;
          _enabledModules['quiz'] = modulesData['quiz'] ?? true;
          _enabledModules['bulletinBoard'] =
              modulesData['bulletinBoard'] ?? true;
          _enabledModules['parkingCommunity'] =
              modulesData['parkingCommunity'] ?? true;
          _enabledModules['wiseOwl'] = modulesData['wiseOwl'] ?? true;
          _enabledModules['snowCleaning'] = modulesData['snowCleaning'] ?? true;
          _enabledModules['security'] = modulesData['security'] ?? true;
          _enabledModules['alarm'] = modulesData['alarm'] ?? true;
          _enabledModules['noise'] = modulesData['noise'] ?? true;
          _enabledModules['readings'] = modulesData['readings'] ?? true;
        });
      }
    } catch (e) {
      _logger.e('Greška pri dohvaćanju postavki modula: $e');
    }
  }

  Future<void> _toggleModule(String moduleKey, bool value) async {
    try {
      await FirebaseFirestore.instance
          .collection('countries')
          .doc(widget.countryId)
          .collection('cities')
          .doc(widget.cityId)
          .collection('locations')
          .doc(widget.locationId)
          .update({'enabledModules.$moduleKey': value});

      setState(() {
        _enabledModules[moduleKey] = value;
      });
    } catch (e) {
      _logger.e('Greška pri ažuriranju modula ($moduleKey): $e');
      final localizationService =
          Provider.of<LocalizationService>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${localizationService.translate('errorUpdatingModule') ?? 'Greška pri ažuriranju modula'}: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizationService = Provider.of<LocalizationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizationService.translate('moduleSettings') ??
            'Postavke modula'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: Text(localizationService.translate('officialNotices') ??
                'Službene obavijesti'),
            value: _enabledModules['officialNotices'] ?? true,
            onChanged: (value) => _toggleModule('officialNotices', value),
          ),
          SwitchListTile(
            title:
                Text(localizationService.translate('chatRoom') ?? 'Chat soba'),
            value: _enabledModules['chatRoom'] ?? true,
            onChanged: (value) => _toggleModule('chatRoom', value),
          ),
          SwitchListTile(
            title: Text(localizationService.translate('quiz') ?? 'Kviz'),
            value: _enabledModules['quiz'] ?? true,
            onChanged: (value) => _toggleModule('quiz', value),
          ),
          SwitchListTile(
            title: Text(localizationService.translate('bulletinBoard') ??
                'Oglasna ploča'),
            value: _enabledModules['bulletinBoard'] ?? true,
            onChanged: (value) => _toggleModule('bulletinBoard', value),
          ),
          SwitchListTile(
            title: Text(localizationService.translate('parkingCommunity') ??
                'Parking zajednica'),
            value: _enabledModules['parkingCommunity'] ?? true,
            onChanged: (value) => _toggleModule('parkingCommunity', value),
          ),
          SwitchListTile(
            title:
                Text(localizationService.translate('wiseOwl') ?? 'Mudra sova'),
            value: _enabledModules['wiseOwl'] ?? true,
            onChanged: (value) => _toggleModule('wiseOwl', value),
          ),
          SwitchListTile(
            title: Text(localizationService.translate('snowCleaning') ??
                'Čišćenje snijega'),
            value: _enabledModules['snowCleaning'] ?? true,
            onChanged: (value) => _toggleModule('snowCleaning', value),
          ),
          SwitchListTile(
            title:
                Text(localizationService.translate('security') ?? 'Sigurnost'),
            value: _enabledModules['security'] ?? true,
            onChanged: (value) => _toggleModule('security', value),
          ),
          SwitchListTile(
            title: Text(localizationService.translate('alarm') ?? 'Alarm'),
            value: _enabledModules['alarm'] ?? true,
            onChanged: (value) => _toggleModule('alarm', value),
          ),
          SwitchListTile(
            title: Text(localizationService.translate('noise') ?? 'Buka'),
            value: _enabledModules['noise'] ?? true,
            onChanged: (value) => _toggleModule('noise', value),
          ),
          SwitchListTile(
            title:
                Text(localizationService.translate('readings') ?? 'Očitanja'),
            value: _enabledModules['readings'] ?? true,
            onChanged: (value) => _toggleModule('readings', value),
          ),
        ],
      ),
    );
  }
}
