Alden_CV.pdf lives here. It is GENERATED — do not hand-edit it.

Source:      cv/cv.tex    (LaTeX master; currently a stub full of [PLACEHOLDERS])
Build steps: cv/BUILD.md  (exact command, incl. a no-Tex-installed Docker path)

The file is committed rather than built on the server because native GitHub
Pages cannot compile LaTeX. Phase 2 of docs/latex-cv-phases.md moves this to a
GitHub Actions pipeline, at which point the PDF becomes a build artifact and
this manual step disappears.

Referenced by _data/links.yml -> resume_pdf. If the file is absent, the CV page
(/cv/) automatically hides the "Document (PDF)" tab and the download links, so
a missing PDF degrades gracefully instead of 404ing.
