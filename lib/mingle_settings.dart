import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'mingle_screen.dart';

class MingleSettingsScreen extends StatefulWidget {
  const MingleSettingsScreen({super.key});

  @override
  State<MingleSettingsScreen> createState() => _MingleSettingsScreenState();
}

class _MingleSettingsScreenState extends State<MingleSettingsScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  final picker = ImagePicker();

  List<File> _selectedImages = [];
  String _bio = '';
  String? _gender;
  int? _age;
  String _location = '';
  double _distance = 10;
  bool _isSaving = false;

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 5) return;
    final picked = await picker.pickMultiImage();
    if (picked != null) {
      setState(() {
        final newImages = picked.map((x) => File(x.path)).toList();
        _selectedImages.addAll(newImages.take(5 - _selectedImages.length));
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enable location services')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

    setState(() {
      final place = placemarks.first;
      _location = '${place.locality}, ${place.country}';
    });
  }

  Future<void> _saveMingleSettings() async {
    if (_bio.isEmpty || _gender == null || _age == null || _location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() => _isSaving = true);
    List<String> imageUrls = [];

    for (var file in _selectedImages) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final ref = FirebaseStorage.instance.ref().child('mingle_images/${currentUser.uid}/$fileName');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      imageUrls.add(url);
    }

    await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
      'mingleSettings': {
        'bio': _bio,
        'gender': _gender,
        'age': _age,
        'location': _location,
        'distance': _distance,
        'imageUrls': imageUrls,
        'completedMingleSetup': true,
      }
    });

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MingleScreen()));
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mingle Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add up to 5 pictures', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._selectedImages.asMap().entries.map((entry) {
                  final index = entry.key;
                  final file = entry.value;
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImages.removeAt(index);
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black54,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      )
                    ],
                  );
                }),
                if (_selectedImages.length < 5)
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_a_photo, color: Colors.orange),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Beautiful Bio', style: TextStyle(fontWeight: FontWeight.bold)),
          TextField(
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Tell others something nice...'),
            onChanged: (val) => _bio = val,
          ),
          const SizedBox(height: 20),
          const Text('Gender', style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<String>(
            value: _gender,
            hint: const Text('Select Gender'),
            items: ['Male', 'Female', 'Other'].map((g) {
              return DropdownMenuItem(value: g, child: Text(g));
            }).toList(),
            onChanged: (val) => setState(() => _gender = val),
          ),
          const SizedBox(height: 20),
          const Text('Age', style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<int>(
            value: _age,
            hint: const Text('Select Age'),
            items: List.generate(43, (i) => i + 18).map((age) {
              return DropdownMenuItem(value: age, child: Text(age.toString()));
            }).toList(),
            onChanged: (val) => setState(() => _age = val),
          ),
          const SizedBox(height: 20),
          const Text('Distance Preference (KM)', style: TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: _distance,
            min: 1,
            max: 100,
            divisions: 99,
            label: '${_distance.round()} KM',
            onChanged: (val) => setState(() => _distance = val),
            activeColor: Colors.orange,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Location:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: _location),
                  onChanged: (val) => _location = val,
                  decoration: const InputDecoration(hintText: 'Fetching your location...'),
                ),
              ),
              IconButton(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.gps_fixed, color: Colors.orange),
              )
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveMingleSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save & Continue', style: TextStyle(fontSize: 16)),
            ),
          )
        ]),
      ),
    );
  }
}




