import 'package:flutter/material.dart';
import 'package:stat_iq/constants/app_constants.dart';

class RegionSelectScreen extends StatefulWidget {
  final List<String> selectedRegions;
  
  const RegionSelectScreen({
    super.key,
    required this.selectedRegions,
  });

  @override
  State<RegionSelectScreen> createState() => _RegionSelectScreenState();
}

class _RegionSelectScreenState extends State<RegionSelectScreen> {
  late List<String> _selectedRegions;
  late TextEditingController _searchController;
  late List<String> _filteredRegions;

  // All VEX IQ regions
  final List<String> _allRegions = [
    // US States
    'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California - North', 'California - South', 'California',
    'Colorado', 'Connecticut', 'Delaware', 'Florida', 'Georgia', 'Hawaii', 'Idaho', 'Illinois', 'Indiana',
    'Iowa', 'Kansas', 'Kentucky', 'Louisiana', 'Maine', 'Maryland', 'Massachusetts', 'Michigan',
    'Minnesota', 'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada', 'New Hampshire', 'New Jersey',
    'New Mexico', 'New York', 'North Carolina', 'North Dakota', 'Ohio', 'Oklahoma', 'Oregon', 'Pennsylvania',
    'Rhode Island', 'South Carolina', 'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont',
    'Virginia', 'Washington', 'West Virginia', 'Wisconsin', 'Wyoming', 'District of Columbia', 'Delmarva',
    
    // Canada
    'Alberta/Saskatchewan', 'British Columbia', 'British Columbia (BC)', 'Manitoba',
    'New Brunswick', 'Newfoundland and Labrador', 'Northwest Territories',
    'Nova Scotia', 'Nunavut', 'Ontario', 'Prince Edward Island', 'Quebec',
    'Saskatchewan', 'Yukon',
    
    // Mexico
    'Mexico',
    
    // Europe
    'Austria', 'Belgium', 'Bulgaria', 'Croatia', 'Czech Republic', 'Denmark',
    'Estonia', 'Finland', 'France', 'Germany', 'Greece', 'Hungary', 'Iceland',
    'Ireland', 'Italy', 'Latvia', 'Lithuania', 'Netherlands', 'Norway',
    'Poland', 'Portugal', 'Romania', 'Slovakia', 'Slovenia', 'Spain',
    'Sweden', 'Switzerland', 'United Kingdom',
    
    // Asia
    'China', 'East China', 'West China', 'North China', 'Middle China',
    'Hong Kong', 'India', 'Indonesia', 'Japan', 'Kazakhstan', 'Kuwait',
    'Malaysia', 'Philippines', 'Singapore', 'South Korea', 'Thailand',
    'United Arab Emirates', 'Vietnam', 'Chinese Taipei',
    
    // South America
    'Argentina', 'Bolivia', 'Brazil', 'Chile', 'Colombia', 'Ecuador',
    'Paraguay', 'Peru', 'Uruguay', 'Venezuela',
    
    // Middle East & Africa
    'Bahrain', 'Egypt', 'Israel', 'Jordan', 'Lebanon', 'Morocco',
    'Qatar', 'Saudi Arabia', 'South Africa', 'Turkey',
    
    // Oceania
    'Australia', 'New Zealand', 'Fiji', 'Papua New Guinea',
    
    // Other
    'Afghanistan', 'Albania', 'Algeria', 'American Samoa', 'Andorra',
    'Angola', 'Antigua and Barbuda', 'Armenia', 'Aruba', 'Azerbaijan',
    'Bahamas', 'Bangladesh', 'Barbados', 'Belarus', 'Belize', 'Benin',
    'Bermuda', 'Bhutan', 'Bosnia and Herzegovina', 'Botswana', 'Brunei',
    'Burkina Faso', 'Burundi', 'Cambodia', 'Cameroon', 'Canada',
    'Cape Verde', 'Cayman Islands', 'Central African Republic', 'Chad',
    'Comoros', 'Congo', 'Cook Islands', 'Costa Rica', 'Cuba', 'Cyprus',
    'Democratic Republic of the Congo', 'Djibouti', 'Dominican Republic',
    'East Timor', 'El Salvador', 'Equatorial Guinea', 'Eritrea', 'Eswatini',
    'Ethiopia', 'Falkland Islands', 'French Guiana', 'French Polynesia',
    'French Southern and Antarctic Territories', 'Gabon', 'Gambia',
    'Georgia- Country', 'Ghana', 'Greenland', 'Guam', 'Guatemala',
    'Guinea', 'Guinea-Bissau', 'Guyana', 'Haiti', 'Honduras', 'Iraq',
    'Jamaica', 'Kenya', 'Kiribati', 'Kosovo', 'Kyrgyzstan', 'Laos',
    'Lesotho', 'Liberia', 'Libya', 'Liechtenstein', 'Luxembourg',
    'Macedonia', 'Madagascar', 'Malawi', 'Maldives', 'Mali', 'Malta',
    'Marshall Islands', 'Mauritania', 'Mauritius', 'Micronesia',
    'Moldova', 'Monaco', 'Mongolia', 'Montenegro', 'Mozambique', 'Myanmar',
    'Namibia', 'Nauru', 'Nepal', 'Nicaragua', 'Niger', 'Nigeria',
    'Niue', 'North Korea', 'Northern Mariana Islands', 'Oman', 'Palau',
    'Panama', 'Rwanda', 'Saint Kitts and Nevis', 'Saint Lucia',
    'Saint Vincent and the Grenadines', 'Samoa', 'San Marino',
    'Sao Tome and Principe', 'Senegal', 'Serbia', 'Seychelles',
    'Sierra Leone', 'Solomon Islands', 'Somalia', 'South Sudan',
    'Sri Lanka', 'Sudan', 'Suriname', 'Swaziland', 'Syria', 'Tajikistan',
    'Tanzania', 'Togo', 'Tonga', 'Trinidad and Tobago', 'Tunisia',
    'Turkmenistan', 'Tuvalu', 'Uganda', 'Ukraine', 'Uzbekistan',
    'Vanuatu', 'Vatican City', 'Yemen', 'Zambia', 'Zimbabwe',
  ];

  @override
  void initState() {
    super.initState();
    _selectedRegions = List.from(widget.selectedRegions);
    _searchController = TextEditingController();
    _filteredRegions = List.from(_allRegions);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter(String query) {
    setState(() {
      _filteredRegions = _allRegions
          .where((region) => region.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select VEX IQ Regions'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search regions...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _applyFilter,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedRegions.clear();
                          });
                        },
                        child: const Text('Clear All'),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedRegions = List.from(_filteredRegions);
                          });
                        },
                        child: const Text('Select All'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredRegions.length,
              itemBuilder: (context, index) {
                final region = _filteredRegions[index];
                final isSelected = _selectedRegions.contains(region);
                return CheckboxListTile(
                  title: Text(
                    region,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedRegions.add(region);
                      } else {
                        _selectedRegions.remove(region);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pop(_selectedRegions);
        },
        backgroundColor: AppConstants.vexIQOrange,
        icon: const Icon(Icons.check),
        label: Text('Apply (${_selectedRegions.length})'),
      ),
    );
  }
}

