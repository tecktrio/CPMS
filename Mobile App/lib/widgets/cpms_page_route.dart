import 'package:flutter/material.dart';

import 'cpms_form_page.dart';

Future<T?> openCpmsPage<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<T>(MaterialPageRoute<T>(builder: builder));
}

Future<T?> openCpmsSelectionPage<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  bool scroll = false,
}) {
  return openCpmsPage<T>(
    context: context,
    builder: (context) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: scroll
                ? SingleChildScrollView(child: Builder(builder: builder))
                : Builder(builder: builder),
          ),
        ),
      ),
    ),
  );
}

Future<DateTime?> openCpmsDatePage({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? initialDate,
  TransitionBuilder? builder,
}) {
  final requested = initialDate ?? DateTime.now();
  var selected = requested.isBefore(firstDate)
      ? firstDate
      : requested.isAfter(lastDate)
      ? lastDate
      : requested;
  final form = GlobalKey<FormState>();
  var enterDate = false;
  return openCpmsPage<DateTime>(
    context: context,
    builder: (context) {
      final page = StatefulBuilder(
        builder: (context, setState) => CpmsFormPage(
          title: const Text('Select date'),
          icon: Icons.calendar_today_outlined,
          content: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (enterDate)
                    Form(
                      key: form,
                      child: InputDatePickerFormField(
                        initialDate: selected,
                        firstDate: firstDate,
                        lastDate: lastDate,
                        onDateSaved: (date) => selected = date,
                      ),
                    )
                  else
                    CalendarDatePicker(
                      initialDate: selected,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      onDateChanged: (date) => selected = date,
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setState(() => enterDate = !enterDate),
                      child: Text(enterDate ? 'Use calendar' : 'Enter date'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (enterDate) {
                  if (!form.currentState!.validate()) return;
                  form.currentState!.save();
                }
                Navigator.pop(context, selected);
              },
              child: const Text('Select date'),
            ),
          ],
        ),
      );
      return builder == null ? page : builder(context, page);
    },
  );
}
