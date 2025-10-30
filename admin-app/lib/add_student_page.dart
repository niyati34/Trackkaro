import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddStudentPage extends StatefulWidget {
  @override
  _AddStudentPageState createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final _formKey = GlobalKey<FormState>();

  final _enrollmentNoController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailAddressController = TextEditingController();
  final _classController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _arrivalIdController = TextEditingController();
  final _departureIdController = TextEditingController();

  File? _profileImage; // Optional local preview only

  String? _selectedBusFeesPaid;
  final List<String> _busFeeOptions = ['Yes', 'No'];

  @override
  void initState() {
    super.initState();
    _selectedBusFeesPaid = _busFeeOptions.first; // default Yes/No as per UI

    // Debug environment setup
    print('=== STUDENT PAGE ENVIRONMENT ===');
    print('BACKEND_API: ${dotenv.env['BACKEND_API']}');
    print('Environment loaded: ${dotenv.env.isNotEmpty}');
    print('================================');
  }

  @override
  void dispose() {
    _enrollmentNoController.dispose();
    _nameController.dispose();
    _phoneNumberController.dispose();
    _addressController.dispose();
    _emailAddressController.dispose();
    _classController.dispose();
    _photoUrlController.dispose();
    _arrivalIdController.dispose();
    _departureIdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _submitStudent() async {
    print('=== STUDENT FORM VALIDATION ===');
    print('Form valid: ${_formKey.currentState?.validate() ?? false}');

    if (!_formKey.currentState!.validate()) {
      print('❌ Student form validation failed');
      return;
    }

    final token = await _getToken();
    print('Retrieved token: "$token"');

    if (token == null || token.isEmpty) {
      print('❌ No token found - user needs to login');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Organization not set. Please login again.')),
      );
      return;
    }

    print('=== STUDENT FORM VALUES ===');
    print('Photo URL: "${_photoUrlController.text.trim()}"');
    print('Enrollment Number: "${_enrollmentNoController.text.trim()}"');
    print('Student Name: "${_nameController.text.trim()}"');
    print('Phone: "${_phoneNumberController.text.trim()}"');
    print('Address: "${_addressController.text.trim()}"');
    print('Email: "${_emailAddressController.text.trim()}"');
    print('Bus Fee Paid: "$_selectedBusFeesPaid"');
    print('Arrival ID: "${_arrivalIdController.text.trim()}"');
    print('Departure ID: "${_departureIdController.text.trim()}"');
    print('============================');

    final body = {
      "photo": _photoUrlController.text.trim(),
      "enrollment_number": _enrollmentNoController.text.trim(),
      "student_name": _nameController.text.trim(),
      "student_phone": _phoneNumberController.text.trim(),
      "student_address": _addressController.text.trim(),
      "busfee_paid": (_selectedBusFeesPaid ?? 'No').toLowerCase() == 'yes',
      "email": _emailAddressController.text.trim(),
      "organization_id": token,
    };

    // Only add assignment IDs if they're provided and not empty
    final arrivalId = _arrivalIdController.text.trim();
    final departureId = _departureIdController.text.trim();
    if (arrivalId.isNotEmpty) {
      body["arrival_id"] = arrivalId;
    }
    if (departureId.isNotEmpty) {
      body["departure_id"] = departureId;
    }

    // Console logging for debugging
    print('=== ADD STUDENT DEBUG INFO ===');
    print('URL: ${dotenv.env['BACKEND_API']}/add-student');
    print('Token (organization_id): "$token"');
    print('Request Data: $body');
    print('Raw inputs:');
    print(
        '  - arrival_id: "$arrivalId" ${arrivalId.isEmpty ? '(empty, not included)' : '(included)'}');
    print(
        '  - departure_id: "$departureId" ${departureId.isEmpty ? '(empty, not included)' : '(included)'}');
    print(
        '  - busfee_paid: "${_selectedBusFeesPaid}" -> ${(_selectedBusFeesPaid ?? 'No').toLowerCase() == 'yes'}');
    print('===============================');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 10),
            Text('Adding student...'),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      final res = await http.post(
        Uri.parse('${dotenv.env['BACKEND_API']}/add-student'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      print('=== ADD STUDENT RESPONSE ===');
      print('Status Code: ${res.statusCode}');
      print('Response Body: ${res.body}');
      print('Response Headers: ${res.headers}');
      print('============================');

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (res.statusCode == 201) {
        print('✅ Student added successfully!');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Student added successfully!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        String msg = 'Failed to add student';
        try {
          final err = jsonDecode(res.body);
          msg = err['message'] ?? err['error'] ?? msg;
          print('❌ Error details: $err');
        } catch (parseErr) {
          print('❌ Failed to parse error response: $parseErr');
        }
        print(
            '❌ Failed to add student - Status: ${res.statusCode}, Message: $msg');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('❌ Exception while adding student: $e');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('❌ Network error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Student'),
        backgroundColor: const Color(0xFF03B0C1),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      // Optional avatar preview
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: const Color(0xFFE0F7FA),
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : null,
                        child: _profileImage == null
                            ? IconButton(
                                icon: const Icon(Icons.camera_alt,
                                    color: Color(0xFF03B0C1)),
                                onPressed: _pickImage,
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                Row(children: [
                  Expanded(
                      child: _buildTextField(_enrollmentNoController,
                          'Enrollment No.', Icons.format_list_numbered)),
                  Expanded(
                      child: _buildTextField(
                          _nameController, 'Name', Icons.person)),
                ]),
                Row(children: [
                  Expanded(
                      child: _buildTextField(
                          _phoneNumberController, 'Phone Number', Icons.phone)),
                  Expanded(
                    child: _buildDropdownField(
                      'Bus Fees Paid',
                      _selectedBusFeesPaid,
                      _busFeeOptions,
                      Icons.attach_money,
                      (value) => setState(() => _selectedBusFeesPaid = value),
                    ),
                  ),
                ]),
                Row(children: [
                  Expanded(
                      child: _buildTextField(
                          _addressController, 'Address', Icons.home)),
                  Expanded(
                      child: _buildTextField(_photoUrlController,
                          'Photo URL (optional)', Icons.link,
                          isRequired: false)),
                ]),
                Row(children: [
                  Expanded(
                      child: _buildTextField(_emailAddressController,
                          'Email Address', Icons.email)),
                  Expanded(
                      child: _buildTextField(
                          _classController, 'Class', Icons.school,
                          isRequired: false)),
                ]),
                Row(children: [
                  Expanded(
                      child: _buildTextField(
                          _arrivalIdController,
                          'Arrival Assignment ID (Optional)',
                          Icons.directions_bus,
                          isRequired: false)),
                  Expanded(
                      child: _buildTextField(
                          _departureIdController,
                          'Departure Assignment ID (Optional)',
                          Icons.directions_bus_filled,
                          isRequired: false)),
                ]),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 5, horizontal: 10),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                    ElevatedButton(
                      onPressed: _submitStudent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF03B0C1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        padding: const EdgeInsets.symmetric(
                            vertical: 5, horizontal: 10),
                      ),
                      child: const Text('Add',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String labelText,
    IconData icon, {
    bool isRequired = true,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon, color: const Color(0xFF03B0C1)),
          filled: true,
          fillColor: Colors.grey[200],
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF03B0C1)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red),
          ),
        ),
        validator: (value) {
          if (!isRequired) return null;
          if (value == null || value.isEmpty) {
            return 'Please enter ${labelText.toLowerCase()}';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownField(
    String labelText,
    String? selectedValue,
    List<String> options,
    IconData icon,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownButtonFormField<String>(
        value: selectedValue,
        onChanged: onChanged,
        items: options.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon, color: const Color(0xFF03B0C1)),
          filled: true,
          fillColor: Colors.grey[200],
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF03B0C1)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red),
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select ${labelText.toLowerCase()}';
          }
          return null;
        },
      ),
    );
  }
}
