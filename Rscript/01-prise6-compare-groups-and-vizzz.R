
#   -----------------------------------------------------------------------
#
#   Rscript to create compare groups object need for the post
#
#   -----------------------------------------------------------------------


# 1. Packages -------------------------------------------------------------

library(compareGroups)
library(xml2)
library(htmltools)
library(knitr)
library(kableExtra)
library(ggplot2)
library(data.table)


# 2. Data and global variables --------------------------------------------

# global variables
VARIABLES             = c("Sepal.Length", "Sepal.Width", "Petal.Length", "Petal.Width")
VARIABLES_AND_CLUSTER = c("cluster", VARIABLES)
NB_CLUSTERS           = 3
NSTART                = 100
SEED_KM               = 234

# load dataset
data(iris)
# make it datatable
setDT(iris)
# create iris.x
iris.x = iris[, ..VARIABLES]


# 3. Perform quick clustering with PCA and K-means ------------------------

# PCA scaled
PCA = prcomp(iris.x, scale. = T, center = T)
# add PCA components to iris.x datatable
iris.x = cbind(iris.x, as.data.table(PCA$x))
# see that the two first component explains majority of variability
cumsum(PCA$sdev)/sum(PCA$sdev)

# reproducibility
set.seed(SEED_KM)
# K-means
model.km = kmeans(iris.x[, list(PC1, PC2)], centers = NB_CLUSTERS, nstart = NSTART)
# add cluster columng to iris.x datatable
iris.x$cluster = model.km$cluster
# transform into factor with nice labels
iris.x[, cluster := factor(
  x      = cluster,
  levels = seq_len(NB_CLUSTERS),
  labels = paste("Cluster", seq_len(NB_CLUSTERS))
)]


# 4. Compare clusters -----------------------------------------------------

comparegroups.main = compareGroups(
  formula          = cluster ~ .,
  data             = iris.x[, ..VARIABLES_AND_CLUSTER]
)

comparegroups.main.table = createTable(
  x        = comparegroups.main,
  show.all = T
)

comparegroups.html = suppressWarnings(
  export2md(
    x             = comparegroups.main.table,
    caption       = "",
    header.labels = c(
      "all"       = "All",
      "p.overall" = "p-value"
    )
  )
)


# 5. Compare clusters with graphs and figures -----------------------------

#### Function to generate plot
generatePlot = function(cluster_s, data) {
  general_graph_data = data[!cluster %in% cluster_s, list(PC1, PC2)]
  cluster_graph_data = data[cluster %in% cluster_s, list(PC1, PC2)]
  
  g = ggplot() +
    geom_point(data = general_graph_data, aes(x = PC1, y = PC2), alpha = .3) +
    geom_point(data = cluster_graph_data, aes(x = PC1, y = PC2), color = "red") +
    theme_void()
  
  return(g)
}

#### Function to generate data URI scheme
plotToURI = function(plot, file = NULL, ...) {
  
  if(is.null(file)) file = paste(tempfile(), "png", sep = ".")
  
  ggsave(filename = file, plot = plot, ...)
  uri = knitr::image_uri(file)
  
  return(uri)
}

#### HTML Tables
# create img tags and td tags around
html_block = lapply(paste("Cluster", 1:3), function(cl) {
  p = generatePlot(cl, iris.x)
  uri = plotToURI(p, width = 3, height = 3, units = "cm", dpi = 100)
  
  tags$td(style = "text-align:center;", tags$img(src = uri))
})

# fill the block with td tags in empty cells
html_block = tagList(
  tags$td(style = "text-align:left;"),
  tags$td(style = "text-align:left;"),
  html_block,
  tags$td(style = "text-align:left;")
)

# we wrap the block in a tr tag
html_block = tags$tr(html_block)


#### Parse HTML
# xml instance of comparegroups.html
comparegroups.html.parse = read_html(as.character(comparegroups.html))
# xml instance of html_block
plot_row = read_xml(doRenderTags(html_block, indent = F))

# find reference to the first column after tbody
first_tbody_tr = xml_find_first(comparegroups.html.parse, "//tbody//tr")
# add sibling before first_tbody_tr
xml_add_sibling(first_tbody_tr, .value = plot_row, .where = "before")
comparegroups.html[1] = as.character(comparegroups.html.parse)


#### Render HTML
to_save = comparegroups.html %>%
  kable_styling(font_size = 12, bootstrap_options = "responsive") %>%
  column_spec(column = 2, bold = T)

saveRDS(to_save, file.path(getwd(), "Datas", "01-comparegroups-plots.rds"))
