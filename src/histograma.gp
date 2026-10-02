# histograma.gp

if (!exists("csvfile")) csvfile = "reporte.csv"
if (!exists("outfile")) outfile = csvfile[1:strlen(csvfile)-4] . "_histograma.png"
if (!exists("resolution")) resolution = 10
if (!exists("nbins")) nbins = 5

set datafile separator ","

# Delay statistics (column 5), skipping the header row
stats csvfile using 5 every ::1 nooutput
n_packets = STATS_records
d_min = STATS_min
d_max = STATS_max
d_mean = STATS_mean

raw_width = (d_max - d_min) / nbins
bin_width = ceil(raw_width / resolution) * resolution
if (bin_width <= 0) bin_width = resolution
nbins_real = floor((d_max - d_min) / bin_width) + 1
idx(x) = floor((x - d_min) / bin_width)
bin(x) = bin_width * (idx(x) < nbins_real ? idx(x) : nbins_real - 1) + d_min + bin_width / 2.0

set terminal pngcairo size 1000,600 font "Sans,11"
set output outfile

set title sprintf("Histograma de retardos (%d paquetes) - %s", n_packets, csvfile) noenhanced
set xlabel "Retardo (ns)"
set ylabel "Cantidad de paquetes"
set grid ytics
set key off
set boxwidth bin_width * 0.98
set style fill solid 0.8 border -1
set xrange [d_min - bin_width : d_max + bin_width]
set offsets 0, 0, 1, 0
set yrange [0:*]

set label 1 sprintf("min = %.1f ns\nprom = %.1f ns\nmax = %.1f ns", d_min, d_mean, d_max) at graph 0.98, graph 0.95 right

plot csvfile using (bin($5)):(1) every ::1 smooth freq with boxes lc rgb "#1F5F8B"

print sprintf("Histograma guardado en %s", outfile)
