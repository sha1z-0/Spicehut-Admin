import 'package:flutter/material.dart';

class PrivacyPolicyModal extends StatefulWidget {
  final VoidCallback onAccepted;

  const PrivacyPolicyModal({super.key, required this.onAccepted});

  @override
  State<PrivacyPolicyModal> createState() => _PrivacyPolicyModalState();
}

class _PrivacyPolicyModalState extends State<PrivacyPolicyModal> {
  bool _isScrolledToBottom = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.atEdge &&
          _scrollController.position.pixels != 0) {
        setState(() {
          _isScrolledToBottom = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF7A00),
              Color(0xFFFF9D42),
              Color(0xFFFFA726),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 550),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Header icon
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7A00).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF7A00).withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.privacy_tip_rounded,
                          color: Color(0xFFFF7A00),
                          size: 64,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      const Text(
                        'Terms & Privacy Policy',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      Text(
                        'Please read and accept our terms and privacy policy to continue',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Divider
                      Divider(color: Colors.grey[300]),
                      const SizedBox(height: 16),

                      // Scrollable content
                      Container(
                        constraints: const BoxConstraints(maxHeight: 400),
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PRIVACY POLICY',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Effective Date: February 7, 2026\n'
                                'Last Updated: February 7, 2026\n\n'
                                '1. INTRODUCTION\n'
                                'Welcome to SpiceHut Admin Application ("App"). This application is designed exclusively for authorized restaurant management personnel to facilitate order processing, staff management, inventory control, and business analytics. This Privacy Policy outlines how we collect, use, protect, and disclose information gathered through this application.\n\n'
                                '2. SCOPE AND APPLICABILITY\n'
                                'This Privacy Policy applies only to the SpiceHut Admin Application. This is an internal business tool intended solely for authorized restaurant personnel (Managers, Supervisors, and Administrators). This policy does not apply to customer-facing applications or external websites.\n\n'
                                '3. INFORMATION COLLECTION\n'
                                'We collect the following categories of information:\n\n'
                                '3.1 User Account Information:\n'
                                '• Email addresses and login credentials\n'
                                '• User role (Admin, Manager, Supervisor)\n'
                                '• Department assignment and access permissions\n'
                                '• Profile information and contact details\n\n'
                                '3.2 Business Operations Data:\n'
                                '• Customer orders and order history\n'
                                '• Menu items, pricing, and inventory data\n'
                                '• Order fulfillment times and status updates\n'
                                '• Table management and seating assignments\n'
                                '• Payment transaction summaries (not full payment details)\n\n'
                                '3.3 Analytics and Performance Data:\n'
                                '• Sales revenue and financial metrics\n'
                                '• Peak hours and traffic patterns\n'
                                '• Staff performance indicators\n'
                                '• Customer preference analytics\n'
                                '• System usage statistics and application performance data\n\n'
                                '3.4 Technical Information:\n'
                                '• Device information (device model, OS version)\n'
                                '• App version and update status\n'
                                '• IP addresses and network information\n'
                                '• Crash reports and error logs (for troubleshooting)\n'
                                '• Timestamps of app usage and feature access\n\n'
                                '4. DATA USAGE AND PURPOSE\n'
                                'Collected information is used exclusively for:\n\n'
                                '4.1 Operational Functions:\n'
                                '• Processing and tracking customer orders in real-time\n'
                                '• Managing staff schedules and responsibilities\n'
                                '• Controlling inventory levels and stock management\n'
                                '• Maintaining menu accuracy and availability status\n'
                                '• Generating invoices and sales reports\n\n'
                                '4.2 Business Analytics:\n'
                                '• Creating revenue reports and financial statements\n'
                                '• Identifying sales trends and patterns\n'
                                '• Analyzing staff performance and productivity\n'
                                '• Forecasting demand and optimizing operations\n'
                                '• Understanding peak hours for resource allocation\n\n'
                                '4.3 System Administration:\n'
                                '• User authentication and access control\n'
                                '• Maintaining system security and preventing unauthorized access\n'
                                '• Troubleshooting technical issues and improving app stability\n'
                                '• Application performance monitoring\n'
                                '• Audit logging for compliance and accountability\n\n'
                                '4.4 Management Controls:\n'
                                '• Implementing approval workflows for orders and transactions\n'
                                '• Enforcing role-based access restrictions\n'
                                '• Preventing unauthorized modifications to critical data\n\n'
                                '5. DATA SECURITY\n'
                                '5.1 Security Measures:\n'
                                '• Industry-standard encryption for data in transit (HTTPS/TLS)\n'
                                '• Secure database storage with encryption at rest\n'
                                '• JWT-based authentication with time-limited sessions\n'
                                '• Role-based access control limiting data visibility by user level\n'
                                '• Regular security audits and vulnerability assessments\n'
                                '• Firewall protection and DDoS mitigation\n\n'
                                '5.2 Account Security Responsibilities:\n'
                                'Users must:\n'
                                '• Keep login credentials confidential and never share passwords\n'
                                '• Use strong, unique passwords (minimum 8 characters recommended)\n'
                                '• Log out after each session, especially on shared devices\n'
                                '• Report suspicious activity immediately\n'
                                '• Update passwords regularly and when personnel changes occur\n\n'
                                '6. DATA SHARING AND DISCLOSURE\n'
                                'We do NOT share user data with third parties except:\n'
                                '• Third-party payment processors (for transaction security)\n'
                                '• Cloud infrastructure providers (for data hosting and backup)\n'
                                '• System administrators and authorized IT personnel (for maintenance)\n'
                                '• Legal authorities (only when required by law or warrant)\n\n'
                                '7. DATA RETENTION\n'
                                '• Active user data: Retained during employment and 12 months following termination\n'
                                '• Transaction records: Retained for minimum 7 years for financial compliance\n'
                                '• Backup data: Retained for 90 days for disaster recovery\n'
                                '• Audit logs: Retained for 2 years for security and compliance purposes\n'
                                '• Upon account deletion: Data is securely purged after retention period\n\n'
                                '8. USER RIGHTS AND ACCESS\n'
                                '• Users have the right to access their personal data\n'
                                '• Users can request correction of inaccurate information\n'
                                '• Data export available in standard formats upon request\n'
                                '• Users can request account deletion (subject to legal hold requirements)\n'
                                '• Contact system administrator for data-related requests\n\n'
                                '9. COOKIES AND USER TRACKING\n'
                                '• Session cookies: Used to maintain login status during app usage\n'
                                '• Preference cookies: Used to remember user preferences and settings\n'
                                '• Analytics cookies: Used to understand app usage patterns\n'
                                '• No tracking or profiling outside the application context\n\n'
                                '10. COMPLIANCE AND LEGALITY\n'
                                '• This application complies with standard data protection practices\n'
                                '• PCI DSS compliance for payment-related data (if applicable)\n'
                                '• GDPR compliant where applicable\n'
                                '• Regular compliance audits and reviews\n'
                                '• Legal hold procedures for pending litigation\n\n'
                                '11. CONTACT FOR PRIVACY CONCERNS\n'
                                'For privacy inquiries or concerns:\n'
                                '• Contact: System Administrator\n'
                                '• Method: Internal support ticket or management escalation\n'
                                '• Response time: Within 5 business days\n\n'
                                '12. POLICY CHANGES\n'
                                'We may update this policy with notice to users. Material changes will require explicit user acceptance.\n',
                              ),
                              SizedBox(height: 24),
                              Divider(thickness: 2),
                              SizedBox(height: 24),
                              Text(
                                'TERMS AND CONDITIONS',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 12),
                              Text(
                                '1. ACCEPTANCE OF TERMS\n'
                                'By accessing and using the SpiceHut Admin Application, you accept and agree to be bound by all terms and conditions outlined in this agreement. If you do not agree, you must not use this application.\n\n'
                                '2. AUTHORIZED USE AND USER ELIGIBILITY\n'
                                '2.1 Authorization Requirement:\n'
                                '• This application is strictly reserved for authorized restaurant personnel of Spice Hut\n'
                                '• Only managers, supervisors, and designated administrators are permitted access\n'
                                '• Unauthorized access attempts will be monitored and reported to management\n'
                                '• Users must be at least 18 years of age to use this application\n\n'
                                '2.2 Access Termination:\n'
                                '• Access is automatically revoked when employment ends\n'
                                '• Management may suspend access for policy violations\n'
                                '• Users must return all access credentials immediately upon request\n\n'
                                '3. USER RESPONSIBILITIES AND CONDUCT\n'
                                '3.1 User Obligations:\n'
                                '• Managers are responsible for accurate order entry and processing\n'
                                '• Supervisors must ensure proper employee supervision and scheduling\n'
                                '• Admins are accountable for maintaining menu accuracy and system integrity\n'
                                '• All users must maintain confidentiality of business data\n'
                                '• Users may not share login credentials or account access with others\n'
                                '• Users must comply with all company policies regarding data handling\n\n'
                                '3.2 Prohibited Activities:\n'
                                '• Attempting to bypass security controls or access unauthorized features\n'
                                '• Manipulating order records, financial data, or analytics\n'
                                '• Sharing customer information outside authorized business context\n'
                                '• Using the application for personal, non-business purposes\n'
                                '• Accessing the app while impaired by drugs or alcohol\n'
                                '• Creating false or fraudulent records\n'
                                '• Reverse engineering or attempting to access source code\n'
                                '• Using the app to harass, discriminate, or harm others\n\n'
                                '3.3 Data Handling Requirements:\n'
                                '• Handle customer and financial data responsibly\n'
                                '• Do not download data for unauthorized purposes\n'
                                '• Do not screenshot sensitive information unnecessarily\n'
                                '• Report data breaches or suspicious access immediately\n'
                                '• Lock device or log out when leaving workplace\n\n'
                                '4. INTELLECTUAL PROPERTY RIGHTS\n'
                                '• All application code, design, and features are proprietary to Spice Hut\n'
                                '• Users are granted non-exclusive, non-transferable use rights only\n'
                                '• No rights are granted for modification, copying, or redistribution\n'
                                '• Unauthorized use of intellectual property may result in termination and legal action\n\n'
                                '5. LIMITATION OF LIABILITY\n'
                                '5.1 No Liability For:\n'
                                '• Data loss or corruption from user error or negligence\n'
                                '• Business interruption from system maintenance or downtime\n'
                                '• Unauthorized access due to compromised credentials\n'
                                '• Third-party service disruptions or unavailability\n'
                                '• Inaccurate data entered by users\n\n'
                                '5.2 Liability Caps:\n'
                                '• In no event shall total liability exceed direct damages actually incurred\n'
                                '• Developers are not liable for indirect, consequential, or punitive damages\n'
                                '• Users assume all responsibility for their use of the application\n\n'
                                '6. SYSTEM AVAILABILITY AND MAINTENANCE\n'
                                '• Application availability is not guaranteed\n'
                                '• Scheduled maintenance may be performed with or without notice\n'
                                '• Users should plan critical operations around maintenance windows\n'
                                '• We strive for 99% uptime but provide no uptime guarantees\n'
                                '• Server downtimes for security updates take precedence\n\n'
                                '7. DISPUTE RESOLUTION\n'
                                '• Disputes shall be resolved through internal management escalation\n'
                                '• Mediation may be requested in writing\n'
                                '• Binding arbitration applies if internal resolution fails\n'
                                '• Users waive right to class action litigation\n\n'
                                '8. TERMINATION OF SERVICE\n'
                                '• Management reserves the right to terminate access without cause\n'
                                '• Users may request access termination at any time\n'
                                '• Upon termination: All data access is immediately revoked\n'
                                '• Account data retention follows privacy policy guidelines\n\n'
                                '9. MODIFICATIONS TO TERMS\n'
                                '• Terms may be updated with 14 days notice\n'
                                '• Continued use after notice constitutes acceptance\n'
                                '• Users will be notified of material changes\n'
                                '• Rejection of new terms may result in access termination\n\n'
                                '10. GOVERNING LAW\n'
                                'These terms are governed by applicable local and national laws, with disputes subject to local jurisdiction.\n\n'
                                '11. ENTIRE AGREEMENT\n'
                                'This terms and privacy policy constitutes the entire agreement between user and Spice Hut regarding the application. Any prior verbal or written agreements are superseded by these terms.\n',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

          // Scroll instruction
          if (!_isScrolledToBottom)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_downward, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Please scroll to the bottom to accept',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          // Accept button with gradient
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isScrolledToBottom ? widget.onAccepted : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                disabledBackgroundColor: Colors.grey[300],
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isScrolledToBottom
                  ? Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF7A00),
                            Color(0xFFFFA726),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF7A00).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: const Text(
                          'I ACCEPT',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      alignment: Alignment.center,
                      child: Text(
                        'I ACCEPT',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
