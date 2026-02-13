import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/models/app_config_model.dart';

class AnnouncemnetCardWidget extends StatefulWidget {
  const AnnouncemnetCardWidget({
    super.key,
    required this.promptSheetModel,
  });

  final PromptSheetModel promptSheetModel;

  @override
  State<AnnouncemnetCardWidget> createState() =>
      _AnnouncemnetCardWidgetState();
}

class _AnnouncemnetCardWidgetState
    extends State<AnnouncemnetCardWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            /// 🔽 Scrollable content with indicator
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true, // always visible
                radius: const Radius.circular(10),
                thickness: 6,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12), // 👈 ADD THIS
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        /// Drag handle
                        Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                    
                        const SizedBox(height: 8),
                    
                        Text(
                          widget.promptSheetModel.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge,
                          textAlign: TextAlign.center,
                        ),
                    
                        const SizedBox(height: 16),
                    
                        Text(
                          widget.promptSheetModel.desc,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            /// 🔘 Fixed bottom button
            SizedBox(
              width: width - 32,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "OKAY",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
