import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddDriverPage extends StatefulWidget {
  var driver;

  AddDriverPage({this.driver});

  @override
  _AddDriverPageState createState() => _AddDriverPageState();
}

class _AddDriverPageState extends State<AddDriverPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _salaryController = TextEditingController();
  String _status = 'Active';
  String _selectedRouteNumber = 'Route 1';
  String _selectedBusNumber = 'Bus 1';
  String _selectedShift = 'Shift-1';
  String _selectedTime = 'Morning';
  File? _image;
  String? _token;

  @override
  void initState() {
    super.initState();
    _getOrganizationToken();
  }

  Future<void> _getOrganizationToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('token');
    });
  }

  Future<void> _pickImage() async {
    if (await Permission.photos.request().isGranted) {
      final ImagePicker _picker = ImagePicker();
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          _image = File(image.path);
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permission denied to access photos')),
      );
    }
  }

  Future<void> _submitDriverData() async {
    if (_token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication token not found')),
      );
      return;
    }

    // Use the same URL pattern as your ManageDriverPage
    final url = Uri.parse('${dotenv.env['BACKEND_API']}/add-driver');

    // Backend expects: driver_photo, driver_name, driver_phone, driver_address,
    // organization_id, driver_salary
    final int? salary = int.tryParse(_salaryController.text.trim());
    final driverData = {
      "driver_photo": _image != null
          ? ""
          : "", // optional; sending empty string if not provided
      "driver_name": _nameController.text.trim(),
      "driver_phone": _phoneController.text.trim(),
      "driver_address": _addressController.text.trim(),
      "organization_id": _token,
      "driver_salary": salary ?? _salaryController.text.trim(),
    };

    try {
      print('Sending driver data: $driverData'); // Debug print

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(driverData),
      );

      print('Response status: ${response.statusCode}'); // Debug print
      print('Response body: ${response.body}'); // Debug print

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Driver added successfully')),
        );
        Navigator.pop(context, true);
      } else {
        String msg = 'Failed to add driver';
        try {
          final j = jsonDecode(response.body);
          msg = j['error'] ?? j['message'] ?? msg;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $msg')),
        );
      }
    } catch (error) {
      print('Error adding driver: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred while adding driver')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Driver'),
        backgroundColor: Color(0xFF03B0C1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildImagePicker(),
            Expanded(
              child: Form(
                key: _formKey,
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(1),
                    1: FlexColumnWidth(1),
                  },
                  children: [
                    TableRow(children: [
                      _buildTextField(_nameController, 'Name', Icons.person),
                      _buildTextField(
                          _phoneController, 'Phone Number', Icons.phone),
                    ]),
                    TableRow(children: [
                      _buildTextField(
                          _addressController, 'Address', Icons.home),
                      _buildDropdown(
                        _selectedRouteNumber,
                        'Route Number',
                        ['Route 1', 'Route 2', 'Route 3'],
                        (newValue) {
                          setState(() {
                            _selectedRouteNumber = newValue!;
                          });
                        },
                      ),
                    ]),
                    TableRow(children: [
                      _buildDropdown(
                        _selectedBusNumber,
                        'Bus Number',
                        ['Bus 1', 'Bus 2', 'Bus 3'],
                        (newValue) {
                          setState(() {
                            _selectedBusNumber = newValue!;
                          });
                        },
                      ),
                      _buildTextField(
                          _salaryController, 'Salary', Icons.monetization_on),
                    ]),
                    TableRow(children: [
                      _buildDropdown(
                        _selectedShift,
                        'Shift',
                        ['Shift-1', 'Shift-2'],
                        (newValue) {
                          setState(() {
                            _selectedShift = newValue!;
                          });
                        },
                      ),
                      _buildDropdown(
                        _selectedTime,
                        'Time',
                        ['Morning', 'Evening'],
                        (newValue) {
                          setState(() {
                            _selectedTime = newValue!;
                          });
                        },
                      ),
                    ]),
                    TableRow(children: [
                      _buildDropdown(_status, 'Status', ['Active', 'Inactive'],
                          (newValue) {
                        setState(() {
                          _status = newValue!;
                        });
                      }),
                      Column(
                        children: [
                          SizedBox(), // Empty cell for alignment
                          SizedBox(height: 16.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              SizedBox(
                                width: 80,
                                height: 35,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      _submitDriverData();
                                    }
                                  },
                                  child: Text(
                                    'Add',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF03B0C1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                        vertical: 5, horizontal: 10),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                height: 35,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                        vertical: 5, horizontal: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String labelText, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon, color: Color(0xFF03B0C1)),
          filled: true,
          fillColor: Colors.grey[200],
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Color(0xFF03B0C1)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.red),
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter ${labelText.toLowerCase()}';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown(String value, String labelText, List<String> items,
      ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownButtonFormField<String>(
        value: value,
        onChanged: onChanged,
        items: items.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(Icons.arrow_drop_down, color: Color(0xFF03B0C1)),
          filled: true,
          fillColor: Colors.grey[200],
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Color(0xFF03B0C1)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        Center(
          child: GestureDetector(
            onTap: _pickImage,
            child: _image != null
                ? Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      image: DecorationImage(
                        image: FileImage(_image!),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: Colors.grey, width: 2),
                    ),
                  )
                : Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.grey, width: 2),
                    ),
                    child: Icon(Icons.camera_alt,
                        size: 50, color: Colors.grey[700]),
                  ),
          ),
        ),
        SizedBox(height: 16.0),
        if (_image != null)
          ElevatedButton(
            onPressed: () {
              setState(() {
                _image = null;
              });
            },
            child: Text(
              'Remove Image',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            ),
          ),
      ],
    );
  }
}
