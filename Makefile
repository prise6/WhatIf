
##
## Globals
##

RSCRIPT_INTERPRETER=Rscript


##
## Commands
##

compare_groups: compare_groups Rmarkdown/01-prise6-compare-groups-and-vizzz.Rmd Datas/01-comparegroups-plots.rds
	$(RSCRIPT_INTERPRETER) -e "rmarkdown::render('Rmarkdown/01-prise6-compare-groups-and-vizzz.Rmd', output_format='github_document', output_file='01-compare-groups-and-visualisation.md', output_dir='Md', knit_root_dir = '~/Projets/WhatIf')"
	touch compare_groups