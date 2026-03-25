import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:john_estacio_website/core/utils/time_zone_service.dart';
import 'package:john_estacio_website/features/performances/data/performances_repository.dart';
import 'package:john_estacio_website/features/performances/domain/models/performance_models.dart';
import 'package:john_estacio_website/core/utils/google_apps_script_mailer.dart';
import 'package:john_estacio_website/features/works/data/works_repository.dart';
import 'package:john_estacio_website/features/works/domain/models/work_model.dart' as wm;
import 'package:john_estacio_website/theme.dart';
import 'package:john_estacio_website/core/utils/title_normalizer.dart';

class RequestScoresPage extends StatefulWidget {
  const RequestScoresPage({super.key});

  @override
  State<RequestScoresPage> createState() => _RequestScoresPageState();
}

class _RequestScoresPageState extends State<RequestScoresPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = PerformancesRepository();
  final _mailer = GoogleAppsScriptMailer();

  // Requester
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _instructions = TextEditingController();
  // Need-by date (scores delivery deadline)
  final TextEditingController _needByText = TextEditingController();
  DateTime? _needBy;

  // Show
  final _conductor = TextEditingController();
  final _ensemble = TextEditingController();
  // Stores selected works as encoded keys: "<id>|<title>|<subtitle>"
  final List<String> _selectedWorkKeys = [];
  final List<PerformanceItem> _performances = [];
  String? _preselectTitle; // from ?work=TITLE query param

  @override
  void initState() {
    super.initState();
    // Ensure there is one blank performance on initial presentation
    if (_performances.isEmpty) {
      _performances.add(
        PerformanceItem(
          venueName: '',
          dateTime: Timestamp.fromMillisecondsSinceEpoch(0),
          timeZoneId: '',
          city: '',
          region: '',
          country: '',
          ticketingLink: '',
        ),
      );
    }
    // Capture preselect work title from query param (resolved to an ID once works load)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final qp = GoRouterState.of(context).uri.queryParameters;
      final pre = qp['work'];
      if (pre != null && pre.trim().isNotEmpty) {
        setState(() => _preselectTitle = pre.trim());
      }
    });
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _instructions.dispose();
    _needByText.dispose();
    _conductor.dispose();
    _ensemble.dispose();
    super.dispose();
  }

   Future<void> _submit() async {
     if (_performances.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Add at least one performance.')),
       );
       return;
     }
     if (_formKey.currentState?.validate() != true) return;

     final req = PerformanceRequest(
       id: '',
       // Persist plain titles for compatibility with existing queries and admin views
       works: _selectedWorkKeys
           .map((k) => k.split('|'))
           .where((parts) => parts.length >= 2)
           .map((parts) => parts[1].trim())
           .toList(),
       conductor: _conductor.text.trim(),
       ensemble: _ensemble.text.trim(),
       performances: _performances,
       requester: RequesterInfo(
         firstName: _firstName.text.trim(),
         lastName: _lastName.text.trim(),
         phone: _phone.text.trim(),
         email: _email.text.trim(),
         address: _address.text.trim(),
         specialInstructions: _instructions.text.trim(),
       ),
        needBy: _needBy == null ? null : Timestamp.fromDate(DateTime(_needBy!.year, _needBy!.month, _needBy!.day)),
       status: RequestStatus.newRequest,
       createdAt: Timestamp.now(),
     );

     try {
        await _repo.addRequest(req);
        await _repo.addAdminMessageForRequest(req);
        final sent = await _mailer.sendScoreRequestEmail(req);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.successGreen,
              content: Text(
                sent
                    ? 'Request submitted. A confirmation receipt has been sent.'
                    : 'Request submitted. Email confirmation could not be sent right now.',
                style: const TextStyle(color: AppTheme.white),
              ),
            ),
          );
          context.go('/performances/upcoming');
        }
      } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Could not submit request: $e')),
         );
       }
     }
   }

   void _showRequestSummary() {
     // Validate before showing summary
     if (_formKey.currentState?.validate() != true) return;

     String fmtDate(Timestamp ts) {
       if (ts.millisecondsSinceEpoch == 0) return 'Not set';
       final d = ts.toDate().toLocal();
       return DateFormat("EEEE, MMMM dd, yyyy 'at' h:mm a").format(d);
     }

     List<Widget> bulletList(List<String> items) {
       return items
           .where((e) => e.trim().isNotEmpty)
           .map((e) => Padding(
                 padding: const EdgeInsets.only(bottom: 4),
                 child: Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Text('• ', style: TextStyle(color: AppTheme.darkGray)),
                     Expanded(
                       child: Text(
                         e,
                         style: const TextStyle(color: AppTheme.darkGray),
                       ),
                     ),
                   ],
                 ),
               ))
           .toList();
     }

      // Convert selected work keys to user-facing labels, always include subtitle when present
      List<String> selectedWorks = _selectedWorkKeys
          .map((k) => k.split('|'))
          .where((parts) => parts.isNotEmpty)
          .map((parts) {
            final title = parts.length >= 2 ? parts[1].trim() : parts.first.trim();
            final subtitle = parts.length >= 3 ? parts[2].trim() : '';
            return subtitle.isNotEmpty ? '$title ($subtitle)' : title;
          })
          .toList();
     // Keep order as chosen; no special sorting required in the summary

      showDialog(
       context: context,
       barrierDismissible: false,
       builder: (dialogCtx) {
         return AlertDialog(
           backgroundColor: AppTheme.white,
           title: const Text(
             'Request Summary',
             style: TextStyle(
               color: AppTheme.darkGray,
               fontWeight: FontWeight.bold,
             ),
           ),
           content: SingleChildScrollView(
             child: DefaultTextStyle(
               style: const TextStyle(color: AppTheme.darkGray),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   // Selected Works
                   const Text(
                     'Selected Works',
                     style: TextStyle(fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: 6),
                   if (selectedWorks.isEmpty)
                     const Text('No works selected')
                   else ...bulletList(selectedWorks),
                   const SizedBox(height: 12),

                   // Performance Details (Ensemble/Conductor)
                   const Text(
                     'Performance Details',
                     style: TextStyle(fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: 6),
                   ...bulletList([
                     if (_ensemble.text.trim().isNotEmpty)
                       'Ensemble: ${_ensemble.text.trim()}',
                     if (_conductor.text.trim().isNotEmpty)
                       'Conductor: ${_conductor.text.trim()}',
                   ]),
                   const SizedBox(height: 6),

                   // Performances block
                   for (int i = 0; i < _performances.length; i++) ...[
                     Text(
                       'Performance ${i + 1}',
                       style: const TextStyle(fontWeight: FontWeight.bold),
                     ),
                     const SizedBox(height: 4),
                     ...bulletList([
                       'Date & Time: ${fmtDate(_performances[i].dateTime)}',
                       if (_performances[i].venueName.trim().isNotEmpty)
                         'Venue: ${_performances[i].venueName.trim()}',
                       [
                         _performances[i].city.trim(),
                         _performances[i].region.trim(),
                         _performances[i].country.trim(),
                       ].where((e) => e.isNotEmpty).join(', ').isNotEmpty
                           ? 'Location: ' + [
                               _performances[i].city.trim(),
                               _performances[i].region.trim(),
                               _performances[i].country.trim(),
                             ].where((e) => e.isNotEmpty).join(', ')
                           : '',
                       if (_performances[i].ticketingLink.trim().isNotEmpty)
                         'Ticketing: ${_performances[i].ticketingLink.trim()}',
                     ]),
                     const SizedBox(height: 8),
                   ],

                   const SizedBox(height: 12),
                   const Text(
                     'Requester Information',
                     style: TextStyle(fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: 6),
                   ...bulletList([
                     'First Name: ${_firstName.text.trim()}',
                     'Surname: ${_lastName.text.trim()}',
                     'Phone Number: ${_phone.text.trim()}',
                     'Email Address: ${_email.text.trim()}',
                     'Courier Delivery Address: ${_address.text.trim()}',
                     if (_instructions.text.trim().isNotEmpty)
                       'Special instructions: ${_instructions.text.trim()}',
                      if (_needBy != null)
                        'Score needed by: ${DateFormat('EEEE, MMMM dd, yyyy').format(_needBy!)}',
                   ]),
                 ],
               ),
             ),
           ),
           actions: [
             TextButton(
               onPressed: () => Navigator.of(dialogCtx).pop(),
               child: const Text('Cancel'),
             ),
             ElevatedButton(
               onPressed: () {
                 Navigator.of(dialogCtx).pop();
                 _submit();
               },
               style: ElevatedButton.styleFrom(
                 backgroundColor: AppTheme.primaryOrange,
                 foregroundColor: AppTheme.black,
                 side: const BorderSide(color: AppTheme.black, width: 1),
                 textStyle: const TextStyle(
                   letterSpacing: 1.0,
                   fontWeight: FontWeight.w600,
                 ),
               ),
               child: const Text('SUBMIT REQUEST'),
             ),
           ],
         );
       },
     );
   }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Request Scores',
                      style: AppTheme.theme.textTheme.headlineLarge
                          ?.copyWith(color: AppTheme.primaryOrange)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _Section(
                            title: 'Performance Details',
                            child: Column(
                              children: [
                                // Swap: Ensemble (required) first, then Conductor
                                _TwoCol(
                                  isWide: isWide,
                                  left: _buildText(
                                    _ensemble,
                                    'Ensemble',
                                    required: true,
                                    hintText:
                                        'Edmonton Symphony Orchestra (ESO)',
                                  ),
                                  right: _buildText(
                                    _conductor,
                                    'Conductor (optional)',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Performances before Select Works
                                _PerformancesEditor(
                                  performances: _performances,
                                  onChanged: () => setState(() {}),
                                ),
                                const SizedBox(height: 12),
                                _WorksSelector(
                                  selected: _selectedWorkKeys,
                                  preselectTitle: _preselectTitle,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _Section(
                            title: 'Requester Information',
                            child: Column(
                              children: [
                                _TwoCol(
                                  isWide: isWide,
                                  left: _buildText(_firstName, 'First Name',
                                      required: true),
                                  right: _buildText(_lastName, 'Surname',
                                      required: true),
                                ),
                                const SizedBox(height: 12),
                                _TwoCol(
                                  isWide: isWide,
                                  left: _buildText(_phone, 'Phone Number',
                                      required: true),
                                  right: _buildText(_email, 'Email Address',
                                      required: true, isEmail: true),
                                ),
                                const SizedBox(height: 12),
                                _buildText(_address, 'Courier Delivery Address',
                                    required: true, maxLines: 2),
                                const SizedBox(height: 12),
                                _NeedByDateField(
                                  controller: _needByText,
                                  selectedDate: _needBy,
                                  onPick: () async {
                                    final themed = Theme.of(context).copyWith(
                                      datePickerTheme: const DatePickerThemeData(
                                        backgroundColor: AppTheme.darkGray,
                                        headerBackgroundColor: AppTheme.primaryOrange,
                                        headerForegroundColor: AppTheme.black,
                                        dayForegroundColor: WidgetStatePropertyAll<Color>(AppTheme.white),
                                        todayForegroundColor: WidgetStatePropertyAll<Color>(AppTheme.black),
                                        todayBackgroundColor: WidgetStatePropertyAll<Color>(AppTheme.primaryOrange),
                                        yearForegroundColor: WidgetStatePropertyAll<Color>(AppTheme.white),
                                      ),
                                    );
                                    final now = DateTime.now();
                                    final picked = await showDatePicker(
                                      context: context,
                                      firstDate: DateTime(now.year - 1),
                                      lastDate: DateTime(now.year + 5),
                                      initialDate: _needBy ?? now,
                                      builder: (context, child) => Theme(data: themed, child: child!),
                                    );
                                    if (picked == null) return;
                                    setState(() {
                                      _needBy = DateTime(picked.year, picked.month, picked.day);
                                      _needByText.text = DateFormat('EEEE, MMMM dd, yyyy').format(_needBy!);
                                    });
                                  },
                                  onClear: () {
                                    setState(() {
                                      _needBy = null;
                                      _needByText.text = '';
                                    });
                                  },
                                  validator: (_) => _needBy == null ? 'Required' : null,
                                ),
                                const SizedBox(height: 12),
                                _buildText(
                                  _instructions,
                                  'Special instructions (optional)',
                                  required: false,
                                  maxLines: 3,
                                  hintText: 'String count, number of scores, …',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => context.pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _showRequestSummary,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          foregroundColor: AppTheme.black,
                          side: const BorderSide(color: AppTheme.black, width: 1),
                          textStyle: const TextStyle(
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('SUBMIT REQUEST'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildText(
    TextEditingController c,
    String label, {
    bool required = false,
    bool isEmail = false,
    int maxLines = 1,
    String? hintText,
  }) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: AppTheme.white,
        labelStyle: const TextStyle(color: AppTheme.darkGray),
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.lightGray),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.lightGray),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
        ),
      ),
      style: const TextStyle(color: AppTheme.darkGray),
      validator: (v) {
        if (!required) return null;
        if (v == null || v.trim().isEmpty) return 'Required';
        if (isEmail && !v.contains('@')) return 'Enter a valid email';
        return null;
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: AppTheme.theme.textTheme.titleLarge
                    ?.copyWith(color: AppTheme.primaryOrange)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _TwoCol extends StatelessWidget {
  const _TwoCol({required this.isWide, required this.left, required this.right});
  final bool isWide;
  final Widget left;
  final Widget right;
  @override
  Widget build(BuildContext context) {
    if (!isWide) return Column(children: [left, const SizedBox(height: 12), right]);
    return Row(children: [
      Expanded(child: left),
      const SizedBox(width: 12),
      Expanded(child: right)
    ]);
  }
}

class _NeedByDateField extends StatelessWidget {
  const _NeedByDateField({required this.controller, required this.selectedDate, required this.onPick, this.onClear, this.validator});
  final TextEditingController controller;
  final DateTime? selectedDate;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onPick,
      decoration: InputDecoration(
        labelText: 'Score needed by',
        hintText: 'Pick a date',
        filled: true,
        fillColor: AppTheme.white,
        labelStyle: const TextStyle(color: AppTheme.darkGray),
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.lightGray),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.lightGray),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Pick date',
              icon: const Icon(Icons.event, color: AppTheme.primaryOrange),
              onPressed: onPick,
            ),
            if (selectedDate != null)
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.clear, color: AppTheme.darkGray),
                onPressed: () {
                  onClear?.call();
                },
              ),
          ],
        ),
      ),
      style: const TextStyle(color: AppTheme.darkGray),
      validator: validator,
    );
  }
}

class _WorksSelector extends StatelessWidget {
  const _WorksSelector({required this.selected, this.preselectTitle});
  // Selected works encoded as "<id>|<title>|<subtitle>"
  final List<String> selected;
  // Optional title to preselect (from query param). If multiple matches, first is selected.
  final String? preselectTitle;

  bool _equalsLoose(String a, String b) => sameTitle(a, b);

  @override
  Widget build(BuildContext context) {
    final worksRepo = WorksRepository();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Works'),
        const SizedBox(height: 8),
        StreamBuilder<List<wm.Work>>(
          stream: worksRepo.getWorksStream(),
          builder: (context, snapshot) {
            final works = List<wm.Work>.from(snapshot.data ?? const <wm.Work>[]);
            if (works.isEmpty) {
              return const Text('No works available.');
            }
            // Sort alphabetically (normalized), tie-break by subtitle
            works.sort((a, b) {
              final t = sortKeyTitle(a.title).compareTo(sortKeyTitle(b.title));
              if (t != 0) return t;
              final sa = (a.subtitle ?? '').toLowerCase().trim();
              final sb = (b.subtitle ?? '').toLowerCase().trim();
              return sa.compareTo(sb);
            });
            // Count duplicates by normalized title
            final Map<String, int> titleCounts = {};
            for (final w in works) {
              final key = normalizeTitle(w.title);
              titleCounts[key] = (titleCounts[key] ?? 0) + 1;
            }

            // Apply preselection by title once (choose first match), if provided and not already selected
            if (preselectTitle != null && preselectTitle!.trim().isNotEmpty) {
                final alreadySelectedByTitle = selected.any((s) {
                final parts = s.split('|');
                final title = parts.length >= 2 ? parts[1].trim() : '';
                  return sameTitle(title, preselectTitle!);
              });
              if (!alreadySelectedByTitle) {
                final match = works.firstWhere(
                  (w) => sameTitle(w.title, preselectTitle!),
                  orElse: () => works.first,
                );
                final key = '${match.id}|${match.title}|${match.subtitle}';
                selected.add(key);
              }
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: works.map((w) {
                final title = w.title;
                // Determine selection strictly by unique ID
                final isSel = selected.any((s) => s.startsWith('${w.id}|'));
                final hasDup = (titleCounts[normalizeTitle(title)] ?? 0) > 1;
                final sub = (w.subtitle).trim();
                // When duplicate titles exist, append subtitle in parentheses for disambiguation
                final labelText = hasDup && sub.isNotEmpty ? '$title ($sub)' : title;
                return FilterChip(
                  label: Text(
                    labelText,
                    style: TextStyle(
                      color: isSel ? AppTheme.primaryOrange : AppTheme.lightGray,
                    ),
                  ),
                  showCheckmark: true,
                  checkmarkColor: AppTheme.primaryOrange,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: isSel ? AppTheme.primaryOrange : AppTheme.lightGray,
                    ),
                  ),
                  backgroundColor: AppTheme.darkGray,
                  selectedColor: AppTheme.darkGray,
                  selected: isSel,
                  onSelected: (_) {
                    if (isSel) {
                      // Remove by ID key prefix
                      selected.removeWhere((s) => s.startsWith('${w.id}|'));
                    } else {
                      final key = '${w.id}|${w.title}|${w.subtitle}';
                      if (!selected.any((s) => s.startsWith('${w.id}|'))) {
                        selected.add(key);
                      }
                    }
                    (context as Element).markNeedsBuild();
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _PerformancesEditor extends StatelessWidget {
  const _PerformancesEditor({required this.performances, required this.onChanged});
  final List<PerformanceItem> performances;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Performances'),
        const SizedBox(height: 8),
        if (performances.isEmpty)
          const Text('No performances added yet.')
        else
          Column(
            children: [
              for (int i = 0; i < performances.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _PerformanceFormCard(
                    key: ValueKey('perf_form_$i'),
                    initial: performances[i],
                    canRemove: performances.length > 1,
                    onChanged: (updated) {
                      performances[i] = updated;
                      onChanged();
                    },
                    onRemove: () {
                      performances.removeAt(i);
                      onChanged();
                    },
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryOrange, width: 1),
              ),
              onPressed: () {
                // When adding, pre-populate with values from the last form (if any)
                if (performances.isNotEmpty) {
                  final last = performances.last;
                  performances.add(PerformanceItem(
                    venueName: last.venueName,
                    dateTime: last.dateTime,
                    timeZoneId: last.timeZoneId,
                    city: last.city,
                    region: last.region,
                    country: last.country,
                    ticketingLink: last.ticketingLink,
                  ));
                } else {
                  performances.add(PerformanceItem(
                    venueName: '',
                    dateTime: Timestamp.fromMillisecondsSinceEpoch(0),
                    timeZoneId: '',
                    city: '',
                    region: '',
                    country: '',
                    ticketingLink: '',
                  ));
                }
                onChanged();
              },
              icon: const Icon(Icons.add, color: AppTheme.darkGray),
              label: const Text('+ Add Performance',
                  style: TextStyle(color: AppTheme.primaryOrange)),
            ),
          ],
        ),
      ],
    );
  }
}

class _PerformanceFormCard extends StatefulWidget {
  const _PerformanceFormCard({super.key, required this.initial, required this.onChanged, required this.onRemove, this.canRemove = true});
  final PerformanceItem initial;
  final ValueChanged<PerformanceItem> onChanged;
  final VoidCallback onRemove;
  final bool canRemove;

  @override
  State<_PerformanceFormCard> createState() => _PerformanceFormCardState();
}

class _PerformanceFormCardState extends State<_PerformanceFormCard> {
  late final TextEditingController _venue;
  late final TextEditingController _city;
  late final TextEditingController _region;
  late final TextEditingController _country;
  late final TextEditingController _ticket;
  late final TextEditingController _timeZoneId;
  late final TextEditingController _dateText;
  DateTime? _dateTime;
  bool _tzManuallySet = false;

  @override
  void initState() {
    super.initState();
    _venue = TextEditingController(text: widget.initial.venueName);
    _city = TextEditingController(text: widget.initial.city);
    _region = TextEditingController(text: widget.initial.region);
    _country = TextEditingController(text: widget.initial.country);
    _ticket = TextEditingController(text: widget.initial.ticketingLink);
    _timeZoneId = TextEditingController(text: widget.initial.timeZoneId);
    _tzManuallySet = widget.initial.timeZoneId.trim().isNotEmpty;
    final ms = widget.initial.dateTime.millisecondsSinceEpoch;
    _dateTime = ms == 0
        ? null
        : TimeZoneService.toZonedLocal(widget.initial.dateTime.toDate().toUtc(), widget.initial.timeZoneId);
    _dateText = TextEditingController(text: _dateTime == null ? '' : _dateLabel());
    _venue.addListener(_emit);
    _city.addListener(_emit);
    _region.addListener(_emit);
    _country.addListener(_emit);
    _ticket.addListener(_emit);
    _timeZoneId.addListener(() {
      _tzManuallySet = _timeZoneId.text.trim().isNotEmpty;
      _emit();
    });
  }

  @override
  void dispose() {
    _venue.dispose();
    _city.dispose();
    _region.dispose();
    _country.dispose();
    _ticket.dispose();
    _timeZoneId.dispose();
    _dateText.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(_buildItem());
  }

  PerformanceItem _buildItem() {
    final tzId = _timeZoneId.text.trim();
    DateTime? utc;
    if (_dateTime != null && tzId.isNotEmpty) {
      utc = TimeZoneService.wallClockToUtc(_dateTime!, tzId);
    }
    return PerformanceItem(
      venueName: _venue.text.trim(),
      dateTime: utc == null ? Timestamp.fromMillisecondsSinceEpoch(0) : Timestamp.fromDate(utc),
      timeZoneId: tzId,
      city: _city.text.trim(),
      region: _region.text.trim(),
      country: _country.text.trim(),
      ticketingLink: _ticket.text.trim(),
    );
  }

  String _dateLabel() {
    if (_dateTime == null) return 'Pick Date & Time';
    return DateFormat("EEEE, MMMM dd, yyyy 'at' h:mm a").format(_dateTime!);
    }

  Future<void> _pickDateTime() async {
    final themed = Theme.of(context).copyWith(
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AppTheme.darkGray,
        headerBackgroundColor: AppTheme.primaryOrange,
        headerForegroundColor: AppTheme.black,
        dayForegroundColor: WidgetStatePropertyAll<Color>(AppTheme.white),
        todayForegroundColor: WidgetStatePropertyAll<Color>(AppTheme.black),
        todayBackgroundColor: WidgetStatePropertyAll<Color>(AppTheme.primaryOrange),
        yearForegroundColor: WidgetStatePropertyAll<Color>(AppTheme.white),
      ),
      timePickerTheme: const TimePickerThemeData(
        backgroundColor: AppTheme.darkGray,
        dialBackgroundColor: AppTheme.black,
        dialHandColor: AppTheme.primaryOrange,
        hourMinuteTextColor: AppTheme.black,
        hourMinuteColor: AppTheme.primaryOrange,
        dayPeriodTextColor: AppTheme.white,
      ),
    );

    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: _dateTime ?? now,
      builder: (context, child) => Theme(data: themed, child: child!),
    );
    if (pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _dateTime != null
          ? TimeOfDay(hour: _dateTime!.hour, minute: _dateTime!.minute)
          : const TimeOfDay(hour: 19, minute: 30),
      builder: (context, child) => Theme(data: themed, child: child!),
    );
    if (pickedTime == null) return;
    setState(() {
      _dateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      _dateText.text = _dateLabel();
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.of(context).size.width < 600;
    final tzIds = TimeZoneService.allTimeZoneIds;

    void applySuggestedTimeZoneIfNeeded() {
      if (_tzManuallySet) return;
      final suggestions = TimeZoneService.suggestTimeZoneIds(
        venueName: _venue.text,
        city: _city.text,
        region: _region.text,
        country: _country.text,
      );
      if (suggestions.isEmpty) return;
      if (_timeZoneId.text.trim().isEmpty || _timeZoneId.text.trim() != suggestions.first) {
        _timeZoneId.text = suggestions.first;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Performance Information'),
                if (widget.canRemove)
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _venue,
              decoration: const InputDecoration(
                labelText: 'Venue Name',
                filled: true,
                fillColor: AppTheme.white,
                labelStyle: TextStyle(color: AppTheme.darkGray),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.lightGray),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.lightGray),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
                ),
              ),
              style: const TextStyle(color: AppTheme.darkGray),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 8),
<<<<<<< HEAD
=======
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _timeZoneId.text.trim()),
              optionsBuilder: (value) {
                applySuggestedTimeZoneIfNeeded();
                final q = value.text.trim().toLowerCase();
                final suggestions = TimeZoneService.suggestTimeZoneIds(
                  venueName: _venue.text,
                  city: _city.text,
                  region: _region.text,
                  country: _country.text,
                );
                final base = <String>[...suggestions, ...tzIds];
                if (q.isEmpty) return base.take(25);
                return base.where((id) => id.toLowerCase().contains(q)).take(25);
              },
              onSelected: (v) {
                setState(() {
                  _tzManuallySet = true;
                  _timeZoneId.text = v;
                });
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                controller.text = _timeZoneId.text;
                controller.addListener(() {
                  // Keep backing controller in sync for _buildItem()
                  if (_timeZoneId.text != controller.text) {
                    _timeZoneId.text = controller.text;
                  }
                });
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Time Zone (IANA)',
                    hintText: 'e.g. America/Edmonton',
                    filled: true,
                    fillColor: AppTheme.white,
                    labelStyle: TextStyle(color: AppTheme.darkGray),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.lightGray),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.lightGray),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
                    ),
                  ),
                  style: const TextStyle(color: AppTheme.darkGray),
                  validator: (v) {
                    final id = (v ?? '').trim();
                    if (id.isEmpty) return 'Required';
                    if (TimeZoneService.tryGetLocation(id) == null) return 'Unknown time zone';
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 8),
>>>>>>> first commit
            if (!isPhone)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _city,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        filled: true,
                        fillColor: AppTheme.white,
                        labelStyle: TextStyle(color: AppTheme.darkGray),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
                        ),
                      ),
                      style: const TextStyle(color: AppTheme.darkGray),
                      onChanged: (_) => applySuggestedTimeZoneIfNeeded(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _region,
                      decoration: const InputDecoration(
                        labelText: 'Province/State/Region',
                        filled: true,
                        fillColor: AppTheme.white,
                        labelStyle: TextStyle(color: AppTheme.darkGray),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
                        ),
                      ),
                      style: const TextStyle(color: AppTheme.darkGray),
                      onChanged: (_) => applySuggestedTimeZoneIfNeeded(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _country,
                      decoration: const InputDecoration(
                        labelText: 'Country',
                        filled: true,
                        fillColor: AppTheme.white,
                        labelStyle: TextStyle(color: AppTheme.darkGray),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.lightGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
                        ),
                      ),
                      style: const TextStyle(color: AppTheme.darkGray),
                      onChanged: (_) => applySuggestedTimeZoneIfNeeded(),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  TextFormField(
                    controller: _city,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      filled: true,
                      fillColor: AppTheme.white,
                      labelStyle: TextStyle(color: AppTheme.darkGray),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.lightGray),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.lightGray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
                      ),
                    ),
                    style: const TextStyle(color: AppTheme.darkGray),
                    onChanged: (_) => applySuggestedTimeZoneIfNeeded(),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _region,
                    decoration: const InputDecoration(
                      labelText: 'Province/State/Region',
                      filled: true,
                      fillColor: AppTheme.white,
                      labelStyle: TextStyle(color: AppTheme.darkGray),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.lightGray),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.lightGray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
                      ),
                    ),
                    style: const TextStyle(color: AppTheme.darkGray),
                    onChanged: (_) => applySuggestedTimeZoneIfNeeded(),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _country,
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      filled: true,
                      fillColor: AppTheme.white,
                      labelStyle: TextStyle(color: AppTheme.darkGray),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.lightGray),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.lightGray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
                      ),
                    ),
                    style: const TextStyle(color: AppTheme.darkGray),
                    onChanged: (_) => applySuggestedTimeZoneIfNeeded(),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ticket,
              decoration: const InputDecoration(
                labelText: 'Ticketing Link (optional)',
                filled: true,
                fillColor: AppTheme.white,
                labelStyle: TextStyle(color: AppTheme.darkGray),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.lightGray),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.lightGray),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
                ),
              ),
              style: const TextStyle(color: AppTheme.darkGray),
            ),
            const SizedBox(height: 8),
            TextFormField(
              readOnly: true,
              onTap: _pickDateTime,
              decoration: InputDecoration(
                labelText: 'Date & Time',
                hintText: 'Pick Date & Time',
                filled: true,
                fillColor: AppTheme.white,
                labelStyle: const TextStyle(color: AppTheme.darkGray),
                border: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.lightGray),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.lightGray),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Pick date & time',
                      icon: const Icon(Icons.event, color: AppTheme.primaryOrange),
                      onPressed: _pickDateTime,
                    ),
                    if (_dateTime != null)
                      IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear, color: AppTheme.darkGray),
                        onPressed: () {
                          setState(() {
                            _dateTime = null;
                            _dateText.text = '';
                          });
                          _emit();
                        },
                      ),
                  ],
                ),
              ),
              style: const TextStyle(color: AppTheme.darkGray),
              controller: _dateText,
              validator: (_) => _dateTime == null ? 'Please select date & time' : null,
            ),
<<<<<<< HEAD
            const SizedBox(height: 8),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _timeZoneId.text.trim()),
              optionsBuilder: (value) {
                applySuggestedTimeZoneIfNeeded();
                final q = value.text.trim().toLowerCase();
                final suggestions = TimeZoneService.suggestTimeZoneIds(
                  venueName: _venue.text,
                  city: _city.text,
                  region: _region.text,
                  country: _country.text,
                );
                final base = <String>[...suggestions, ...tzIds];
                if (q.isEmpty) return base.take(25);
                return base.where((id) => id.toLowerCase().contains(q)).take(25);
              },
              onSelected: (v) {
                setState(() {
                  _tzManuallySet = true;
                  _timeZoneId.text = v;
                });
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                controller.text = _timeZoneId.text;
                controller.addListener(() {
                  // Keep backing controller in sync for _buildItem()
                  if (_timeZoneId.text != controller.text) {
                    _timeZoneId.text = controller.text;
                  }
                });
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Time Zone (IANA)',
                    hintText: 'e.g. America/Edmonton',
                    filled: true,
                    fillColor: AppTheme.white,
                    labelStyle: TextStyle(color: AppTheme.darkGray),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.lightGray),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.lightGray),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2.0),
                    ),
                  ),
                  style: const TextStyle(color: AppTheme.darkGray),
                  validator: (v) {
                    final id = (v ?? '').trim();
                    if (id.isEmpty) return 'Required';
                    if (TimeZoneService.tryGetLocation(id) == null) return 'Unknown time zone';
                    return null;
                  },
                );
              },
            ),
=======
>>>>>>> first commit
          ],
        ),
      ),
    );
  }
}
