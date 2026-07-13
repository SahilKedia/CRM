class Review {
  final String id;
  final String customerName;
  final String? customerEmail;
  final String branch;
  final int rating;
  final String comments;
  final String status;
  final DateTime createdAt;
  final DateTime? submittedAt;
  final Map<String, dynamic>? customer;

  Review({
    required this.id,
    required this.customerName,
    this.customerEmail,
    required this.branch,
    required this.rating,
    required this.comments,
    required this.status,
    required this.createdAt,
    this.submittedAt,
    this.customer,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    String name = '';
    String? email;
    
    if (json['customer'] != null && json['customer'] is Map<String, dynamic>) {
      name = json['customer']['name'] ?? '';
      email = json['customer']['email'];
    } else if (json['customerName'] != null) {
      name = json['customerName'];
      email = json['customerEmail'];
    }

    return Review(
      id: json['_id'] ?? json['id'] ?? '',
      customerName: name,
      customerEmail: email,
      branch: json['branch'] ?? '',
      rating: json['rating'] ?? 0,
      comments: json['comments'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      submittedAt: json['submittedAt'] != null 
          ? DateTime.tryParse(json['submittedAt']) 
          : null,
      customer: json['customer'],
    );
  }
}