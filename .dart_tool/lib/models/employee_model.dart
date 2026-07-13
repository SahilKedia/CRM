class Employee {
  final String id;
  final String name;
  final String? email; // Optional
  final String phone;
  final String department;
  final String branch;
  final String address;
  final String emergencyContact;
  final DateTime createdAt;
  final DateTime updatedAt;

  Employee({
    required this.id,
    required this.name,
    this.email,
    required this.phone,
    required this.department,
    required this.branch,
    this.address = '',
    this.emergencyContact = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'],
      phone: json['phone'] ?? '',
      department: json['department'] ?? '',
      branch: json['branch'] ?? '',
      address: json['address'] ?? '',
      emergencyContact: json['emergencyContact'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      if (email != null) 'email': email,
      'phone': phone,
      'department': department,
      'branch': branch,
      'address': address,
      'emergencyContact': emergencyContact,
    };
  }
}
