# Aim: generate diff for peer review


download.file(
  "https://github.com/Hussein-Mahfouz/cycle-networks/raw/ce4827fc708d510bead10d4998ce7ba875286d0d/README.Rmd",
  "paper-original-submission.Rmd"
  )
file.edit("paper-original-submission.Rmd")
rmarkdown::render("paper-original-submission.Rmd")
system("latexdiff paper-original-submission.tex README.tex > tracked-changes.tex")
tinytex::pdflatex("tracked-changes.tex")
browseURL("tracked-changes.pdf")
