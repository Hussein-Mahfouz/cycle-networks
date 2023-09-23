# Aim: generate diff for peer review

# ROUND 1: Robin

# download.file(
#   "https://github.com/Hussein-Mahfouz/cycle-networks/raw/ce4827fc708d510bead10d4998ce7ba875286d0d/README.Rmd",
#   "paper-original-submission.Rmd"
#   )
# file.edit("paper-original-submission.Rmd")
# rmarkdown::render("paper-original-submission.Rmd")
# system("latexdiff paper-original-submission.tex README.tex > tracked-changes.tex")
# tinytex::pdflatex("tracked-changes.tex")
# browseURL("tracked-changes.pdf")

# ROUND 2: Hussein

# download paper version submitted after round 1 of reviews -> save it as "paper_round_1"
download.file(
  "https://github.com/Hussein-Mahfouz/cycle-networks/blob/c3b74611e92b4092af487c1bc179187c9e1608bb/README.Rmd",
  "paper_round_1.Rmd"
)
file.edit("paper_round_1.Rmd")
rmarkdown::render("paper_round_1.Rmd")
# compare with current version and create tracked changes
system("latexdiff paper_round_1.tex README.tex > tracked-changes_2.tex")
tinytex::pdflatex("tracked-changes_2.tex")
browseURL("tracked-changes_2.pdf")


# ROUND 3: Hussein

file.edit("paper_drafts/paper_round_2.Rmd")
rmarkdown::render("paper_drafts/paper_round_2.Rmd")
# compare with current version and create tracked changes
system("latexdiff paper_round_2.tex README.tex > tracked-changes_3.tex")
tinytex::pdflatex("tracked-changes_3.tex")
browseURL("tracked-changes_3.pdf")
