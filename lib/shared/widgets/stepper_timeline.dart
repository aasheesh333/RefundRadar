import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

class StepperTimeline extends StatelessWidget {
  final List<StepperItem> items;
  const StepperTimeline({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final isLast = i == items.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.isDone
                          ? const Color(0xFF16C784)
                          : item.isCurrent
                              ? const Color(0xFF0B3D2E)
                              : Colors.grey.shade300,
                    ),
                    child: Center(
                      child: item.isDone
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : Text('${i + 1}',
                              style: TextStyle(
                                  color: item.isCurrent ? Colors.white : Colors.grey.shade600,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 60,
                      color: item.isDone ? const Color(0xFF16C784) : Colors.grey.shade300,
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(child: item.child),
            ],
          ),
        );
      }),
    );
  }
}

class StepperItem {
  final String title;
  final bool isDone;
  final bool isCurrent;
  final Widget child;
  const StepperItem({
    required this.title,
    required this.isDone,
    required this.isCurrent,
    required this.child,
  });
}

class WizardStepCard extends StatelessWidget {
  final String title;
  final String body;
  final String? url;
  final String? phone;
  final String? emailAddress;
  final String? complaintText;
  final List<String> documents;
  final VoidCallback? onDone;
  final String doneLabel;

  const WizardStepCard({
    super.key,
    required this.title,
    required this.body,
    this.url,
    this.phone,
    this.emailAddress,
    this.complaintText,
    this.documents = const [],
    this.onDone,
    this.doneLabel = 'Done — set reminder',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(body),
            if (complaintText != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(complaintText!),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Clipboard.setData(ClipboardData(text: complaintText!)),
                icon: const Icon(Icons.copy),
                label: const Text('Copy complaint text'),
              ),
            ],
            if (url != null) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _launchUrl(context, url!),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open portal'),
              ),
            ],
            if (phone != null) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _launchUrl(context, 'tel:$phone'),
                icon: const Icon(Icons.phone),
                label: Text('Call $phone'),
              ),
            ],
            if (emailAddress != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    _launchUrl(context, 'mailto:$emailAddress?subject=Complaint'),
                icon: const Icon(Icons.email),
                label: const Text('Email'),
              ),
            ],
            if (documents.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Documents needed:', style: Theme.of(context).textTheme.titleSmall),
              ...documents.map((d) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(d)),
                    ]),
                  )),
            ],
            if (onDone != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: onDone, child: Text(doneLabel)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _launchUrl(BuildContext context, String url) {
    // url_launcher launch is wired in wizard page wrapper; this just shows for now
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open: $url')));
  }
}
