Alden_CV.pdf lives here. It is GENERATED — do not hand-edit it.

Source:      cv/cv.tex    (LaTeX master; currently a stub full of [PLACEHOLDERS])
Rebuild:     ./cv/build.sh     (Docker — no TeX or pandoc needed on the host)
Full docs:   cv/BUILD.md

`cv/cv.tex` produces TWO files, and they ship together:

  assets/pdf/Alden_CV.pdf    this PDF — the fidelity / print / ATS view,
                             shown on the "Document (PDF)" tab of /cv/
  _includes/cv-live.html     the same document as HTML, rendered by pandoc,
                             shown on the "Document (HTML)" tab of /cv/

Both are committed even though they are generated, for two reasons: native
GitHub Pages cannot compile LaTeX or run pandoc, and Jekyll's `include` tag
raises an error when a file is missing — so a CI-only cv-live.html would break
local builds.

.github/workflows/deploy.yml runs ./cv/build.sh on every push to main, so the
deployed copies are always regenerated from cv/cv.tex and cannot go stale. CI
also fails the build if either artifact differs from cv.tex (i.e. the .tex was
edited without re-running the build).

Both artifacts are byte-reproducible, so identical input gives identical bytes.
pdfTeX would otherwise stamp the current time into the PDF's CreationDate on
every run; cv/build.sh pins SOURCE_DATE_EPOCH to stop that. That is what lets CI
byte-compare this file, and it means a modified PDF in `git status` is a real
change rather than build noise.

Referenced by _data/links.yml -> resume_pdf. If this file is absent, the CV page
(/cv/) automatically hides both document tabs and the download links, so a
missing PDF degrades gracefully instead of 404ing.

After editing cv/cv.tex, re-run ./cv/build.sh and commit cv.tex together with
both regenerated artifacts.

