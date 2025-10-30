class StudentRecord {
  final String id;
  final String enrollmentNumber;
  final String name;
  final String phone;
  final String busNumber;
  final String address;
  final bool busFeePaid;
  final String email;

  const StudentRecord({
    required this.id,
    required this.enrollmentNumber,
    required this.name,
    required this.phone,
    required this.busNumber,
    required this.address,
    required this.busFeePaid,
    required this.email,
  });

  factory StudentRecord.fromJson(Map<String, dynamic> json) {
    final rawPaid = json['busfee_paid'];
    final boolPaid = rawPaid == true ||
        rawPaid == 1 ||
        (rawPaid is String &&
            (rawPaid.toLowerCase() == 'true' || rawPaid == '1'));
    return StudentRecord(
      id: (json['id'] ?? '').toString(),
      enrollmentNumber: json['enrollment_number'] ?? 'N/A',
      name: json['student_name'] ?? 'N/A',
      phone: json['student_phone'] ?? 'N/A',
      busNumber: json['bus_number'] ?? 'N/A',
      address: json['student_address'] ?? 'N/A',
      busFeePaid: boolPaid,
      email: json['email'] ?? 'N/A',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'enrollment_number': enrollmentNumber,
        'student_name': name,
        'student_phone': phone,
        'bus_number': busNumber,
        'student_address': address,
        'busfee_paid': busFeePaid,
        'email': email,
      };
}
