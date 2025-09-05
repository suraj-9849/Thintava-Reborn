import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFFFB703),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildSection(
              'Information We Collect',
              [
                'Personal Information: Name, email address, phone number, and profile details when you register.',
                'Order Information: Food items ordered, delivery preferences, payment details, and order history.',
                'Device Information: Device ID, model, and operating system for single-device authentication.',
                'Location Data: Optional location information for delivery services.',
                'Payment Information: Payment methods and transaction details (securely processed through Razorpay).',
              ],
            ),
            _buildSection(
              'How We Use Your Information',
              [
                'Process and fulfill your food orders from our canteen.',
                'Manage user accounts and provide customer support.',
                'Send order confirmations, updates, and notifications.',
                'Improve our app functionality and user experience.',
                'Ensure account security through device-based authentication.',
                'Generate QR codes for order tracking and pickup.',
              ],
            ),
            _buildSection(
              'Data Sharing and Storage',
              [
                'We use Google Firebase for secure data storage and authentication.',
                'Payment processing is handled securely by Razorpay.',
                'We do not sell or share your personal information with third parties.',
                'Data is stored on secure servers with encryption and access controls.',
                'Staff may access order information only to fulfill your requests.',
              ],
            ),
            _buildSection(
              'Your Rights',
              [
                'Access and update your profile information at any time.',
                'View your complete order history within the app.',
                'Delete your account and associated data upon request.',
                'Opt-out of promotional notifications (order updates will still be sent).',
                'Contact us for any data-related concerns or questions.',
              ],
            ),
            _buildSection(
              'Security Measures',
              [
                'Single-device authentication to prevent unauthorized access.',
                'Encrypted data transmission and storage.',
                'Regular security updates and monitoring.',
                'Secure payment processing through certified providers.',
                'Limited access to personal information by authorized personnel only.',
              ],
            ),
            _buildSection(
              'Cookies and Tracking',
              [
                'We use minimal tracking for app functionality.',
                'No third-party advertising cookies are used.',
                'Analytics data is anonymized and used for app improvement.',
                'Local storage is used for user preferences and session management.',
              ],
            ),
            _buildSection(
              'Updates to Privacy Policy',
              [
                'We may update this policy to reflect changes in our practices.',
                'Significant changes will be communicated through the app.',
                'Continued use of the app indicates acceptance of updated terms.',
                'Previous versions of this policy are available upon request.',
              ],
            ),
            _buildContactSection(),
            const SizedBox(height: 30),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB703).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.privacy_tip_outlined,
                  color: Color(0xFFFFB703),
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Privacy Matters',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Last updated: ${DateTime.now().toString().split(' ')[0]}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            'This Privacy Policy explains how our canteen app collects, uses, and protects your personal information. We are committed to maintaining your privacy and ensuring the security of your data.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> points) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFFB703),
            ),
          ),
          const SizedBox(height: 15),
          ...points.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFB703),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    point,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB703).withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFFFB703).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.contact_support_outlined,
                color: Color(0xFFFFB703),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Contact Us',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFFB703),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'If you have any questions about this Privacy Policy or how we handle your data, please contact us through the app\'s feedback system or reach out to our support team.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        'Canteen App v1.0.0\nCommitted to protecting your privacy',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 11,
          color: Colors.grey[500],
          height: 1.3,
        ),
      ),
    );
  }
}