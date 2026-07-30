import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('standard text and dropdown fields share the app outline',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const AppTextField(
                decoration: InputDecoration(
                  labelText: 'Name',
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                ),
              ),
              AppDropdownField<String>(
                labelText: 'Gender',
                initialValue: 'female',
                items: const [
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                ],
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    final textBorder =
        textField.decoration!.enabledBorder! as OutlineInputBorder;
    final dropdownBorder =
        dropdown.decoration.enabledBorder! as OutlineInputBorder;

    expect(textBorder.borderRadius, BorderRadius.circular(28));
    expect(dropdownBorder.borderRadius, textBorder.borderRadius);
    expect(dropdownBorder.borderSide.color, textBorder.borderSide.color);
  });
}
