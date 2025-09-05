import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Terms of Service',
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
              'Acceptance of Terms',
              [
                'By downloading and using this canteen app, you agree to be bound by these Terms of Service.',
                'If you do not agree with any part of these terms, you may not use our service.',
                'These terms apply to all users, including students, staff, and visitors.',
                'We reserve the right to update these terms at any time with notice through the app.',
              ],
            ),
            _buildSection(
              'Account Registration and Security',
              [
                'You must provide accurate and complete information when creating an account.',
                'You are responsible for maintaining the confidentiality of your account credentials.',
                'Each account is limited to one device for security purposes.',
                'Sharing your account with others is strictly prohibited.',
                'You must immediately notify us of any unauthorized use of your account.',
              ],
            ),
            _buildSection(
              'Service Usage',
              [
                'This app is designed for ordering food from our canteen facility.',
                'You may only place orders for personal consumption during operating hours.',
                'All orders are subject to availability and our canteen\'s operating schedule.',
                'We reserve the right to refuse or cancel orders at our discretion.',
                'QR codes generated for orders are for your use only and should not be shared.',
              ],
            ),
            _buildSection(
              'Payment and Pricing',
              [
                'All prices are displayed in the local currency and include applicable taxes.',
                'Payment must be completed before order preparation begins.',
                'We use Razorpay for secure payment processing.',
                'Refunds are subject to our refund policy and cancellation terms.',
                'We reserve the right to modify prices without prior notice.',
              ],
            ),
            _buildSection(
              'Order Policies',
              [
                'Orders can be cancelled within the allowed time frame before preparation begins.',
                'No-show for pickup may result in order cancellation without refund.',
                'Special dietary requests are accommodated subject to availability.',
                'We are not liable for allergic reactions; please check ingredients carefully.',
                'Order modifications after confirmation may not always be possible.',
              ],
            ),
            _buildSection(
              'Stock and Availability',
              [
                'Menu items are subject to availability and stock limitations.',
                'We use a stock reservation system to manage inventory.',
                'Items may become unavailable during peak hours.',
                'We strive to update availability in real-time but cannot guarantee accuracy.',
                'Substitute items may be offered if ordered items become unavailable.',
              ],
            ),
            _buildSection(
              'User Conduct',
              [
                'Users must conduct themselves respectfully when interacting with staff.',
                'Fraudulent activities or abuse of the system will result in account termination.',
                'False information in orders or complaints is prohibited.',
                'Users should report technical issues through proper channels.',
                'Spam, harassment, or misuse of the feedback system is not tolerated.',
              ],
            ),
            _buildSection(
              'Limitation of Liability',
              [
                'We provide the service "as is" without warranties of any kind.',
                'We are not liable for delays, cancellations, or service interruptions.',
                'Our total liability is limited to the amount paid for the specific order.',
                'We are not responsible for device compatibility or connectivity issues.',
                'Force majeure events may affect service availability without liability.',
              ],
            ),
            _buildSection(
              'Privacy and Data',
              [
                'Your use of this app is also governed by our Privacy Policy.',
                'We collect and use data as described in our Privacy Policy.',
                'You consent to data processing necessary for service provision.',
                'Account deletion will remove personal data subject to legal requirements.',
              ],
            ),
            _buildSection(
              'Termination',
              [
                'You may delete your account at any time through the app settings.',
                'We may suspend or terminate accounts for violation of these terms.',
                'Upon termination, your right to use the service ceases immediately.',
                'Provisions regarding liability and disputes survive termination.',
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
                  Icons.description_outlined,
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
                      'Terms of Service',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Effective date: ${DateTime.now().toString().split(' ')[0]}',
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
            'These Terms of Service govern your use of our canteen ordering app. Please read them carefully as they contain important information about your rights and obligations.',
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
                'Questions or Concerns?',
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
            'If you have any questions about these Terms of Service, please contact our support team through the app\'s help section or feedback system.',
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
        'Canteen App v1.0.0\nThank you for using our service responsibly',
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