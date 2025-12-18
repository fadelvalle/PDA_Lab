# Cargar librerías necesarias
if (!require("tidyverse")) install.packages("tidyverse")
library(tidyverse)

# 1. Configurar la ruta de la carpeta donde están tus CSV
# Cambia 'tu/ruta/de/resultados' por la carpeta real
path_to_csvs <- "~/Documents/TESTING_MACROS/Dendrite analysis/Rscript_analysis"

# Obtener lista de archivos CSV (filtramos por los de intensidad para no duplicar)
files <- list.files(path = path_to_csvs, pattern = "results_intensity_.*\\.csv$", full.names = TRUE)

# Leer todos los archivos y combinarlos en un solo data frame
# Añadimos una columna 'file_name' para identificar el origen
all_data <- files %>%
  map_df(~read_csv(.x) %>% mutate(file_name = basename(.x)))

# ---------------------------------------------------------
# 2, 3 y 4. Procesamiento de datos por imagen
# ---------------------------------------------------------

summary_per_image <- all_data %>%
  group_by(file_name) %>%
  summarise(
    n_labels = n(),  # Cantidad de objetos (Labels)
    img_width_um = first(Img_Width_microns),  # Considera el ancho de la imagen
    img_height_um = first(Img_Height_microns) # Considera el alto de la imagen
  )

# 5. Totales generales
total_labels <- sum(summary_per_image$n_labels)
total_width_sum <- sum(summary_per_image$img_width_um)
total_height_sum <- sum(summary_per_image$img_height_um)

# Mostrar resumen en consola
cat("--- RESUMEN GENERAL ---\n")
print(summary_per_image)
cat("\nTotal de objetos (Labels) detectados:", total_labels, "\n")
cat("Suma total de anchos de imágenes (um):", total_width_sum, "\n")

# ---------------------------------------------------------
# 6. Gráficos de Area y Mean
# ---------------------------------------------------------

# Gráfico de dispersión: Area vs Mean
plot_area_mean <- ggplot(all_data, aes(x = Area, y = Mean, color = file_name)) +
  geom_point(alpha = 0.5) +
  theme_minimal() +
  labs(title = "Relación entre Área e Intensidad Media",
       x = "Área (um^2)",
       y = "Intensidad Media (Gris)",
       color = "Archivo") +
  theme(legend.position = "none") # Quitamos leyenda si son muchos archivos

# Boxplot para ver la distribución de Area por archivo
plot_distribution <- ggplot(all_data, aes(x = file_name, y = Area)) +
  geom_boxplot() +
  coord_flip() +
  theme_minimal() +
  labs(title = "Distribución de Áreas por Imagen",
       x = "Archivo",
       y = "Área")

# Mostrar gráficos
print(plot_area_mean)
print(plot_distribution)


# Creamos el dataframe con los totales acumulados
resumen_final <- data.frame(
  Total_Objetos = total_labels,
  Distancia_Total_um = total_width_sum,
  Puncta_per_100um = (total_labels / total_width_sum) * 100
)

# Mostrar el dataframe resultante
cat("\n--- DATAFRAME DE RESULTADOS FINALES ---\n")
print(resumen_final)

# Opcional: Si quieres guardar este resumen en un CSV en la misma carpeta
# write_csv(resumen_final, file.path(path_to_csvs, "resumen_total_puncta.csv"))
