import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

// ---- MODELY ----

class FinancialIndex {
  final String name;
  final String ticker;
  final Color color;
  final String region;
  final String desc;
  const FinancialIndex({
    required this.name,
    required this.ticker,
    required this.color,
    required this.region,
    required this.desc,
  });
}

class DayData {
  final DateTime date;
  final double close;
  DayData({required this.date, required this.close});
}

// ---- VŠETKY INDEXY (20) ----

const List<FinancialIndex> kAllIndices = [
  // USA
  FinancialIndex(name: 'S&P 500',            ticker: '^GSPC',     color: Color(0xFF2E7D32), region: 'USA',            desc: '500 najväčších amerických spoločností'),
  FinancialIndex(name: 'NASDAQ Composite',   ticker: '^IXIC',     color: Color(0xFFE65100), region: 'USA',            desc: 'Všetky akcie burzy NASDAQ, dôraz na technológie'),
  FinancialIndex(name: 'NASDAQ 100',         ticker: '^NDX',      color: Color(0xFFF57F17), region: 'USA',            desc: '100 najväčších nefinančných firiem na NASDAQ'),
  FinancialIndex(name: 'Dow Jones',          ticker: '^DJI',      color: Color(0xFF1565C0), region: 'USA',            desc: '30 blue-chip amerických priemyselných spoločností'),
  FinancialIndex(name: 'Russell 2000',       ticker: '^RUT',      color: Color(0xFF0288D1), region: 'USA',            desc: '2000 malých amerických spoločností'),
  // Svet
  FinancialIndex(name: 'MSCI World',         ticker: 'URTH',      color: Color(0xFF6A1B9A), region: 'Svet',           desc: '~1 500 akcií z 23 rozvinutých krajín sveta (ETF)'),
  // Európa
  FinancialIndex(name: 'Euro Stoxx 50',      ticker: '^STOXX50E', color: Color(0xFFC62828), region: 'Európa',         desc: '50 blue-chip spoločností z eurozóny'),
  FinancialIndex(name: 'STOXX Europe 600',   ticker: '^STOXX',    color: Color(0xFFAD1457), region: 'Európa',         desc: '600 európskych spoločností zo 17 krajín'),
  FinancialIndex(name: 'FTSE 100',           ticker: '^FTSE',     color: Color(0xFF00695C), region: 'Európa',         desc: '100 najväčších britských spoločností'),
  FinancialIndex(name: 'DAX',                ticker: '^GDAXI',    color: Color(0xFF558B2F), region: 'Európa',         desc: '40 najväčších nemeckých spoločností'),
  FinancialIndex(name: 'CAC 40',             ticker: '^FCHI',     color: Color(0xFF4527A0), region: 'Európa',         desc: '40 najväčších francúzskych spoločností'),
  FinancialIndex(name: 'IBEX 35',            ticker: '^IBEX',     color: Color(0xFF880E4F), region: 'Európa',         desc: '35 najväčších španielskych spoločností'),
  FinancialIndex(name: 'AEX',                ticker: '^AEX',      color: Color(0xFF33691E), region: 'Európa',         desc: '25 najväčších holandských spoločností'),
  FinancialIndex(name: 'BEL 20',             ticker: '^BFX',      color: Color(0xFF1A237E), region: 'Európa',         desc: '20 najväčších belgických spoločností'),
  FinancialIndex(name: 'WIG20',              ticker: 'WIG20.WA',  color: Color(0xFF37474F), region: 'Európa',         desc: '20 najväčších poľských spoločností'),
  // Ázia & Pacifik
  FinancialIndex(name: 'Nikkei 225',         ticker: '^N225',     color: Color(0xFFE53935), region: 'Ázia & Pacifik', desc: '225 blue-chip japonských spoločností'),
  FinancialIndex(name: 'Hang Seng',          ticker: '^HSI',      color: Color(0xFFD84315), region: 'Ázia & Pacifik', desc: 'Hlavné spoločnosti hongkonskej burzy'),
  FinancialIndex(name: 'Shanghai Composite', ticker: '000001.SS', color: Color(0xFF827717), region: 'Ázia & Pacifik', desc: 'Všetky akcie šanghajskej burzy'),
  FinancialIndex(name: 'ASX 200',            ticker: '^AXJO',     color: Color(0xFF00838F), region: 'Ázia & Pacifik', desc: '200 najväčších austrálskych spoločností'),
  // Volatilita
  FinancialIndex(name: 'VIX',                ticker: '^VIX',      color: Color(0xFFBF360C), region: 'Volatilita',     desc: 'Index volatility trhu (Fear Index)'),
];

// Predvolený výber pri prvom spustení
const Set<String> kDefaultTickers = {'^GSPC', '^IXIC', 'URTH', '^STOXX50E', '^STOXX', 'WIG20.WA'};
const String kPrefKey = 'selectedTickers';

// ---- STIAHNUTIE DÁT ----

class YahooFinanceService {
  static Future<List<DayData>> fetchData(String ticker) async {
    final encoded = Uri.encodeComponent(ticker);
    final uri = Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/$encoded?interval=1d&range=3mo',
    );
    final response = await http.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      'Accept': 'application/json',
    });
    if (response.statusCode != 200) throw Exception('Chyba servera: ${response.statusCode}');
    final json = jsonDecode(response.body);
    final result = json['chart']['result'];
    if (result == null || (result as List).isEmpty) throw Exception('Žiadne dáta: $ticker');
    final timestamps = List<int>.from(result[0]['timestamp']);
    final closes = List<dynamic>.from(result[0]['indicators']['quote'][0]['close']);
    final days = <DayData>[];
    for (int i = 0; i < timestamps.length; i++) {
      if (closes[i] != null) {
        days.add(DayData(
          date: DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000),
          close: (closes[i] as num).toDouble(),
        ));
      }
    }
    if (days.length > 65) return days.sublist(days.length - 65);
    return days;
  }
}

// ---- APLIKÁCIA ----

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finančné indexy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ---- DOMOVSKÁ OBRAZOVKA ----

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Set<String> _selectedTickers = kDefaultTickers;
  Future<Map<String, List<DayData>>>? _allDataFuture;
  DateTime? _dataDate;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(kPrefKey);
    if (saved != null && saved.isNotEmpty) {
      setState(() => _selectedTickers = saved.toSet());
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(kPrefKey, _selectedTickers.toList());
  }

  List<FinancialIndex> get _activeIndices =>
      kAllIndices.where((i) => _selectedTickers.contains(i.ticker)).toList();

  Future<Map<String, List<DayData>>> _fetchAll() async {
    final entries = await Future.wait(
      _activeIndices.map((idx) => YahooFinanceService.fetchData(idx.ticker)
          .then((d) => MapEntry(idx.ticker, d))
          .catchError((_) => MapEntry(idx.ticker, <DayData>[]))),
    );
    final data = Map.fromEntries(entries);
    DateTime? maxDate;
    for (final list in data.values) {
      if (list.isNotEmpty) {
        final last = list.last.date;
        if (maxDate == null || last.isAfter(maxDate)) maxDate = last;
      }
    }
    _dataDate = maxDate;
    return data;
  }

  void _load() => setState(() => _allDataFuture = _fetchAll());

  Future<void> _openSettings() async {
    final result = await Navigator.push<Set<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(selectedTickers: Set.from(_selectedTickers)),
      ),
    );
    if (result != null && result != _selectedTickers) {
      setState(() {
        _selectedTickers = result;
        _allDataFuture = null; // reset — user musí znovu načítať
      });
      await _savePrefs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Finančné indexy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            if (_dataDate != null)
              Text(
                'dáta k ${DateFormat('d. M. yyyy').format(_dataDate!)}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _openSettings,
            tooltip: 'Výber indexov',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Načítať / obnoviť dáta',
          ),
        ],
      ),
      body: _allDataFuture == null
          ? _buildWelcome()
          : FutureBuilder<Map<String, List<DayData>>>(
              future: _allDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        Text('Načítavam dáta indexov...'),
                      ],
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 52),
                          const SizedBox(height: 12),
                          Text('${snapshot.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Skúsiť znova'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return CombinedChartView(
                  allData: snapshot.data!,
                  activeIndices: _activeIndices,
                  onRetry: _load,
                );
              },
            ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 20),
            const Text('Finančné indexy',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              _activeIndices.map((i) => i.name).join(' · '),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.6),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Načítať dáta'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('Zmeniť výber indexov'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text('Vyžaduje internetové pripojenie',
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}

// ---- NASTAVENIA — VÝBER INDEXOV ----

class SettingsScreen extends StatefulWidget {
  final Set<String> selectedTickers;
  const SettingsScreen({super.key, required this.selectedTickers});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedTickers);
  }

  void _toggle(String ticker) {
    setState(() {
      if (_selected.contains(ticker)) {
        if (_selected.length > 1) _selected.remove(ticker);
      } else {
        _selected.add(ticker);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Zoskup podľa regiónu v poradí
    final regionOrder = ['USA', 'Svet', 'Európa', 'Ázia & Pacifik', 'Volatilita'];
    final grouped = <String, List<FinancialIndex>>{};
    for (final r in regionOrder) {
      grouped[r] = kAllIndices.where((i) => i.region == r).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Výber indexov', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: const Text('Uložiť',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Info lišta
          Container(
            width: double.infinity,
            color: const Color(0xFF1565C0).withOpacity(0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'Vybrané: ${_selected.length} / ${kAllIndices.length} indexov',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: ListView(
              children: regionOrder.map((region) {
                final indices = grouped[region]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hlavička regiónu
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Text(
                        region,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1565C0),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    // Indexy v regióne
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)
                        ],
                      ),
                      child: Column(
                        children: indices.asMap().entries.map((entry) {
                          final i = entry.key;
                          final idx = entry.value;
                          final isSelected = _selected.contains(idx.ticker);
                          return Column(
                            children: [
                              InkWell(
                                onTap: () => _toggle(idx.ticker),
                                borderRadius: BorderRadius.vertical(
                                  top: i == 0 ? const Radius.circular(12) : Radius.zero,
                                  bottom: i == indices.length - 1
                                      ? const Radius.circular(12)
                                      : Radius.zero,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      // Farebný indikátor
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: idx.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Názov a ticker
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(idx.name,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                )),
                                            Text(idx.desc,
                                                style: TextStyle(
                                                    fontSize: 11, color: Colors.grey[500])),
                                          ],
                                        ),
                                      ),
                                      // Checkbox
                                      Checkbox(
                                        value: isSelected,
                                        onChanged: (_) => _toggle(idx.ticker),
                                        activeColor: const Color(0xFF1565C0),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (i < indices.length - 1)
                                Divider(height: 1, indent: 38, color: Colors.grey[100]),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                );
              }).toList()
                ..add(const SizedBox(height: 20)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- ZLÚČENÝ GRAF ----

class CombinedChartView extends StatefulWidget {
  final Map<String, List<DayData>> allData;
  final List<FinancialIndex> activeIndices;
  final VoidCallback onRetry;

  const CombinedChartView({
    super.key,
    required this.allData,
    required this.activeIndices,
    required this.onRetry,
  });

  @override
  State<CombinedChartView> createState() => _CombinedChartViewState();
}

const _kPeriods = [
  (label: '1T', days: 5,  desc: 'posledný týždeň',    maxPoints: 7),
  (label: '2T', days: 10, desc: 'posledné 2 týždne',  maxPoints: 7),
  (label: '1M', days: 21, desc: 'posledný mesiac',    maxPoints: 15),
  (label: '3M', days: 63, desc: 'posledné 3 mesiace', maxPoints: 15),
];

class _CombinedChartViewState extends State<CombinedChartView> {
  int _periodIdx = 2;
  final Set<String> _hiddenTickers = {};
  String? _rsiTicker;

  int get _days => _kPeriods[_periodIdx].days;

  List<double> _calcRSI(List<double> prices, {int period = 14}) {
    if (prices.length <= period) return [];
    final changes = List.generate(prices.length - 1, (i) => prices[i + 1] - prices[i]);
    double avgG = 0, avgL = 0;
    for (int i = 0; i < period; i++) {
      if (changes[i] > 0) avgG += changes[i]; else avgL -= changes[i];
    }
    avgG /= period; avgL /= period;
    final rsi = <double>[avgL == 0 ? 100.0 : 100 - 100 / (1 + avgG / avgL)];
    for (int i = period; i < changes.length; i++) {
      final g = changes[i] > 0 ? changes[i] : 0.0;
      final l = changes[i] < 0 ? -changes[i] : 0.0;
      avgG = (avgG * (period - 1) + g) / period;
      avgL = (avgL * (period - 1) + l) / period;
      rsi.add(avgL == 0 ? 100.0 : 100 - 100 / (1 + avgG / avgL));
    }
    return rsi;
  }

  List<double> _rsiForPeriod(String ticker) {
    final all = widget.allData[ticker] ?? [];
    final p = _kPeriods[_periodIdx];
    final allRsi = _calcRSI(all.map((d) => d.close).toList());
    if (allRsi.isEmpty) return [];
    final sliced = allRsi.length <= p.days ? allRsi : allRsi.sublist(allRsi.length - p.days);
    return _downsample(sliced, p.maxPoints);
  }

  List<T> _downsample<T>(List<T> data, int maxN) {
    if (data.length <= maxN) return data;
    final result = <T>[];
    for (int i = 0; i < maxN; i++) {
      final idx = ((i * (data.length - 1)) / (maxN - 1)).round();
      result.add(data[idx]);
    }
    return result;
  }

  List<DayData> _slice(String ticker) {
    final d = widget.allData[ticker] ?? [];
    final p = _kPeriods[_periodIdx];
    final sliced = d.length <= p.days ? d : d.sublist(d.length - p.days);
    return _downsample(sliced, p.maxPoints);
  }

  List<DateTime> get _refDates {
    List<DateTime> best = [];
    for (final idx in widget.activeIndices) {
      final d = _slice(idx.ticker);
      if (d.length > best.length) best = d.map((e) => e.date).toList();
    }
    return best;
  }

  List<FlSpot> _pctSpots(List<DayData> data) {
    if (data.isEmpty) return [];
    final first = data.first.close;
    return data.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), ((e.value.close - first) / first) * 100))
        .toList();
  }

  String _fmtPct(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)} %';

  String _fmtVal(double v) {
    if (v >= 10000) return v.toStringAsFixed(0);
    if (v >= 1000) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final refDates = _refDates;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final lineBars = <LineChartBarData>[];
    for (final idx in widget.activeIndices) {
      if (_hiddenTickers.contains(idx.ticker)) continue;
      final spots = _pctSpots(_slice(idx.ticker));
      if (spots.isEmpty) continue;
      lineBars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.3,
        color: idx.color,
        barWidth: 0.6,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, pct, bar, i) => FlDotCirclePainter(
            radius: 3,
            color: idx.color,
            strokeWidth: 0,
            strokeColor: idx.color,
          ),
        ),
        belowBarData: BarAreaData(show: false),
      ));
    }

    double minY = 0, maxY = 0;
    for (final idx in widget.activeIndices) {
      if (_hiddenTickers.contains(idx.ticker)) continue;
      final data = _slice(idx.ticker);
      if (data.isEmpty) continue;
      final first = data.first.close;
      for (final d in data) {
        final pct = ((d.close - first) / first) * 100;
        if (pct < minY) minY = pct;
        if (pct > maxY) maxY = pct;
      }
    }
    final yPad = (maxY - minY).abs() * 0.12 + 0.5;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Legenda + period selector
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Text('Porovnanie indexov',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_kPeriods.length, (i) {
                            final selected = i == _periodIdx;
                            return GestureDetector(
                              onTap: () => setState(() => _periodIdx = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: selected ? const Color(0xFF1565C0) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  _kPeriods[i].label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: selected ? Colors.white : Colors.grey[600],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Builder(builder: (_) {
                    final pcts = widget.activeIndices
                        .where((idx) => !_hiddenTickers.contains(idx.ticker))
                        .map((idx) {
                      final d = _slice(idx.ticker);
                      if (d.isEmpty) return 0.0;
                      return (d.last.close - d.first.close) / d.first.close * 100;
                    }).toList();
                    final avg = pcts.isEmpty ? 0.0 : pcts.reduce((a, b) => a + b) / pcts.length;
                    final isUp = avg >= 0;
                    return Text(
                      'Priemerná zmena za sledované obdobie: ${isUp ? '+' : ''}${avg.toStringAsFixed(2)} %',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isUp ? Colors.green[700] : Colors.red[700],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Graf
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 20, 16, 12),
              child: SizedBox(
                height: isLandscape
                    ? MediaQuery.of(context).size.height * 0.55
                    : 340,
                child: lineBars.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Žiadne dáta'),
                            const SizedBox(height: 12),
                            ElevatedButton(
                                onPressed: widget.onRetry, child: const Text('Obnoviť')),
                          ],
                        ),
                      )
                    : LineChart(LineChartData(
                        minY: minY - yPad,
                        maxY: maxY + yPad,
                        lineBarsData: lineBars,
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: (refDates.length / 5).ceilToDouble(),
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= refDates.length) return const SizedBox();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(DateFormat('d.M').format(refDates[i]),
                                      style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 56,
                              getTitlesWidget: (value, meta) {
                                if (value == meta.min || value == meta.max) return const SizedBox();
                                return Text(
                                  '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)} %',
                                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          getDrawingHorizontalLine: (v) => FlLine(
                            color: v == 0
                                ? Colors.grey.withOpacity(0.6)
                                : Colors.grey.withOpacity(0.12),
                            strokeWidth: v == 0 ? 1.5 : 1,
                            dashArray: v == 0 ? null : [4, 4],
                          ),
                          getDrawingVerticalLine: (_) =>
                              FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.withOpacity(0.3)),
                            left: BorderSide(color: Colors.grey.withOpacity(0.3)),
                          ),
                        ),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => Colors.blueGrey.shade900,
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItems: (touchedSpots) {
                              final slices = widget.activeIndices
                                  .map((i) => _slice(i.ticker))
                                  .toList();
                              return touchedSpots.asMap().entries.map((entry) {
                                final spot = entry.value;
                                final barIdx = spot.barIndex;
                                final idx = barIdx < widget.activeIndices.length
                                    ? widget.activeIndices[barIdx]
                                    : widget.activeIndices[0];
                                final dayIdx = spot.x.toInt();
                                final dateStr = (entry.key == 0 &&
                                        dayIdx >= 0 &&
                                        dayIdx < refDates.length)
                                    ? DateFormat('d. M. yyyy').format(refDates[dayIdx])
                                    : '';
                                final data = slices[barIdx];
                                final price = (dayIdx >= 0 && dayIdx < data.length)
                                    ? _fmtVal(data[dayIdx].close)
                                    : '';
                                return LineTooltipItem(
                                  '${dateStr.isNotEmpty ? '$dateStr\n' : ''}${idx.name}:  $price  (${_fmtPct(spot.y)})',
                                  TextStyle(
                                      color: idx.color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      )),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // RSI panel
          Builder(builder: (_) {
            final rsiIdx = _rsiTicker == null ? null : widget.activeIndices.where((i) => i.ticker == _rsiTicker && !_hiddenTickers.contains(i.ticker)).firstOrNull;
            if (rsiIdx == null) return const SizedBox.shrink();
            final n = _kPeriods[_periodIdx].maxPoints;
            final rsiVals = _rsiForPeriod(rsiIdx.ticker);
            if (rsiVals.isEmpty) return const SizedBox.shrink();
            final bars = <LineChartBarData>[
              LineChartBarData(spots: List.generate(n, (i) => FlSpot(i.toDouble(), 70)), color: Colors.red.withOpacity(0.3), barWidth: 1.2, dotData: FlDotData(show: false), dashArray: [4, 4]),
              LineChartBarData(spots: List.generate(n, (i) => FlSpot(i.toDouble(), 30)), color: Colors.green.withOpacity(0.3), barWidth: 1.2, dotData: FlDotData(show: false), dashArray: [4, 4]),
              LineChartBarData(
                spots: rsiVals.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                isCurved: true, curveSmoothness: 0.3, color: rsiIdx.color, barWidth: 0.6,
                dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 2, color: rsiIdx.color, strokeWidth: 0, strokeColor: rsiIdx.color)),
                belowBarData: BarAreaData(show: false),
              ),
            ];
            final activeRsi = [rsiIdx];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 6),
                      child: Text('RSI · 14 periód · ${rsiIdx.name}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[600])),
                    ),
                    SizedBox(
                      height: 140,
                      child: LineChart(LineChartData(
                        minY: 0, maxY: 100,
                        lineBarsData: bars,
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, interval: (n / 5).ceilToDouble(), getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= refDates.length) return const SizedBox();
                            return Padding(padding: const EdgeInsets.only(top: 4), child: Text(DateFormat('d.M').format(refDates[i]), style: TextStyle(fontSize: 9, color: Colors.grey[600])));
                          })),
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, _) {
                            if (![0.0, 30.0, 70.0, 100.0].contains(v)) return const SizedBox();
                            return Text(v.toInt().toString(), style: TextStyle(fontSize: 9, color: Colors.grey[600]));
                          })),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(show: true,
                          getDrawingHorizontalLine: (v) => FlLine(color: (v == 30 || v == 70) ? Colors.grey.withOpacity(0.4) : Colors.grey.withOpacity(0.1), strokeWidth: (v == 30 || v == 70) ? 1.2 : 1, dashArray: (v == 30 || v == 70) ? [4, 4] : null),
                          getDrawingVerticalLine: (_) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.3)), left: BorderSide(color: Colors.grey.withOpacity(0.3)))),
                        lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => Colors.blueGrey.shade900,
                          getTooltipItems: (spots) => spots.map((s) {
                            if (s.barIndex < 2) return null;
                            final idx = activeRsi[s.barIndex - 2];
                            return LineTooltipItem('${idx.name}: RSI ${s.y.toStringAsFixed(1)}', TextStyle(color: idx.color, fontSize: 10, fontWeight: FontWeight.w600));
                          }).toList(),
                        )),
                      )),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),

          Text('Zmena · ${_kPeriods[_periodIdx].desc}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isLandscape ? 3 : 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: widget.activeIndices.length,
            itemBuilder: (context, i) {
              final idx = widget.activeIndices[i];
              final data = _slice(idx.ticker);
              final isHidden = _hiddenTickers.contains(idx.ticker);
              final isRsi = _rsiTicker == idx.ticker;
              final pct = data.length >= 2 ? (data.last.close - data.first.close) / data.first.close * 100 : null;
              final isUp = (pct ?? 0) >= 0;
              return Opacity(
                opacity: isHidden ? 0.35 : 1.0,
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  clipBehavior: Clip.hardEdge,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Ľavá polovica — toggle viditeľnosti
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              if (isHidden) _hiddenTickers.remove(idx.ticker);
                              else _hiddenTickers.add(idx.ticker);
                            }),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                              child: Row(children: [
                                Container(width: 4, height: 36, decoration: BoxDecoration(color: idx.color, borderRadius: BorderRadius.circular(2))),
                                const SizedBox(width: 8),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(idx.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                    Text(data.isNotEmpty ? _fmtVal(data.last.close) : '—', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                  ],
                                )),
                              ]),
                            ),
                          ),
                        ),
                        // Pravá časť — toggle RSI
                        GestureDetector(
                          onTap: () => setState(() {
                            _rsiTicker = isRsi ? null : idx.ticker;
                          }),
                          child: Container(
                              padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
                              decoration: BoxDecoration(
                                border: Border(left: BorderSide(color: Colors.grey.shade100)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    pct != null ? '${isUp ? '+' : ''}${pct.toStringAsFixed(2)} %' : 'N/A',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: pct == null ? Colors.grey : isUp ? Colors.green[700] : Colors.red[700]),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('RSI', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isRsi ? const Color(0xFF1565C0) : Colors.grey[300])),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),
          Center(
            child: Text('Zdroj dát: Yahoo Finance',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ),
        ],
      ),
    );
  }
}

// ---- SÚHRNNÁ KARTA ----

class _SummaryCard extends StatelessWidget {
  final FinancialIndex idx;
  final double? value;
  final double? pct;
  const _SummaryCard({required this.idx, required this.value, required this.pct});

  String _fmtVal(double v) {
    if (v >= 10000) return v.toStringAsFixed(0);
    if (v >= 1000) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final isUp = (pct ?? 0) >= 0;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 4, height: 36,
              decoration: BoxDecoration(
                  color: idx.color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(idx.name,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  Text(value != null ? _fmtVal(value!) : '—',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            Text(
              pct != null ? '${isUp ? '+' : ''}${pct!.toStringAsFixed(2)} %' : 'N/A',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: pct == null ? Colors.grey : isUp ? Colors.green[700] : Colors.red[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
