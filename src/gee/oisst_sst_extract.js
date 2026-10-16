// Provenance: Google Earth Engine Code Editor script that produced the SST
// covariate, data/sst/2025-11-20_SNE_buoys_sst-data.csv (run 2025-11-20).
// Not run by the R pipeline. Its Drive export is long format
// (id, date, sst_C); the CSV used by 01_data.R is the same data pivoted wide
// (date, COX01, NS01, NS02). Validated against NDBC in-situ WTMP in
// manuscripts/schick_etal_hawkes_SNE/covariate_data/plot_sst_gee_overlay.R.
// Note: the band is °C x 100, not Kelvin as the header line below says; the
// 0.01 scaling in extractForBuoy() is correct.
// Body below is preserved as run.

// === Daily SST time series for three buoys (Southern New England) ===
// Dataset: NOAA OISST v2.1 (0.25°, daily global)
// Select 'sst' band (Kelvin). Convert to °C.

// Image collection:
var sstIC = ee.ImageCollection('NOAA/CDR/OISST/V2_1')
  .select('sst');

// Buffer radius:
var bufferMeters = 2000;     // 2 km
var sampleScale = 5000;      // OISST is 0.25° (~25 km); 5 km sampling is fine

// Buoy coordinates:
var buoys = ee.FeatureCollection([
  ee.Feature(ee.Geometry.Point([-71.10312, 41.14128]), {
    id: 'COX01',
    start: '2021-02-26',
    end:   '2022-10-08'
  }),
  ee.Feature(ee.Geometry.Point([-70.34125, 41.03343]), {
    id: 'NS01',
    start: '2021-03-17',
    end:   '2022-05-29'
  }),
  ee.Feature(ee.Geometry.Point([-70.01428, 40.73645]), {
    id: 'NS02',
    start: '2021-03-10',
    end:   '2022-11-09'
  })
]);

// Helper: daily list of dates
function dailyDates(startStr, endStr) {
  var start = ee.Date(startStr);
  var end   = ee.Date(endStr).advance(1, 'day');
  var nDays = end.difference(start, 'day');
  return ee.List.sequence(0, nDays.subtract(1)).map(function(d) {
    return start.advance(ee.Number(d), 'day');
  });
}

// Extract daily SST for one buoy
function extractForBuoy(feat) {
  var id    = feat.get('id');
  var start = feat.get('start');
  var end   = feat.get('end');
  var dates = dailyDates(start, end);

  var region = feat.geometry().buffer(bufferMeters);

  var feats = dates.map(function(d) {
    d = ee.Date(d);

    var img = ee.Image(
      sstIC.filterDate(d, d.advance(1, 'day')).first()
    );

    // OISST sst is in °C * 100 → multiply by 0.01 to get °C
    var sstC = img.select('sst')
                  .multiply(0.01)
                  .rename('sst_C');

    var meanDict = sstC.reduceRegion({
      reducer: ee.Reducer.mean(),
      geometry: region,
      scale: sampleScale,
      bestEffort: true
    });

    return ee.Feature(null, {
      id: id,
      date: d.format('YYYY-MM-dd'),
      sst_C: meanDict.get('sst_C')
    });
  });

  return ee.FeatureCollection(feats);
}

// Run:
var results = ee.FeatureCollection(
  buoys.toList(buoys.size()).map(function(f) {
    return extractForBuoy(ee.Feature(f));
  })
).flatten();

// Preview table:
print('SST preview:', results.limit(20));

// Chart:
var chart = ui.Chart.feature.groups({
  features: results,
  xProperty: 'date',
  yProperty: 'sst_C',
  seriesProperty: 'id'
}).setOptions({
  title: 'Daily SST (°C) around buoy locations (OISST)',
  hAxis: {title: 'Date'},
  vAxis: {title: 'SST (°C)'}
});
print(chart);

// Export CSV:
Export.table.toDrive({
  collection: results.select(['id', 'date', 'sst_C']),
  description: 'OISST_SST_Southern_New_England_Buoys',
  fileFormat: 'CSV'
});
