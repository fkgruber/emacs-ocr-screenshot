;;; org-ocr-drawer.el --- Automatically add OCR text under images in Org-mode -*- lexical-binding: t -*-

;; Author: Fred Gruber <email {at} fredgruber {dot} org>
;; Version: 0.1
;; Package-Requires: ((emacs "27.1") (org-download "0"))
;; Keywords: org, images, ocr, convenience
;; URL: https://github.com/yourusername/org-ocr-drawer

;;; Commentary:
;;
;; This package adds OCR text under images inserted with org-download,
;; specifically when using `org-download-clipboard`. It creates an
;; :ocr: drawer under the image link containing the OCR output
;; (from either Tesseract or EasyOCR), and folds the drawer automatically.
;;
;; To use:
;;
;; (require 'org-ocr-drawer)
;; (org-ocr-drawer-enable)
;;
;; Customize `org-ocr-drawer-backend` to choose between 'tesseract or 'easyocr.
;;
;; Tesseract must be installed and on your PATH.
;; EasyOCR will automatically install a CLI script if missing.

;;; Code:

(require 'org)
(require 'org-download)
(require 'subr-x)

(defgroup org-ocr-drawer nil
  "Insert OCR output under images in Org-mode."
  :group 'org)

(defcustom org-ocr-drawer-backend 'tesseract
  "OCR backend to use. Must be either 'tesseract or 'easyocr."
  :type '(choice (const :tag "Tesseract" tesseract)
                 (const :tag "EasyOCR" easyocr))
  :group 'org-ocr-drawer)

(defcustom org-ocr-drawer-easyocr-cmd "easyocr-cli"
  "Shell command for running EasyOCR and printing OCR output.
Should accept an image path as its sole argument and print OCR text to stdout."
  :type 'string
  :group 'org-ocr-drawer)

(defcustom org-ocr-drawer-easyocr-conda-env nil
  "Optional conda environment name to activate before running EasyOCR CLI."
  :type '(choice (const :tag "None" nil) string)
  :group 'org-ocr-drawer)

(defcustom org-ocr-drawer-easyocr-script-dir "~/bin/"
  "Directory where the EasyOCR CLI script will be written if not found."
  :type 'directory
  :group 'org-ocr-drawer)

(defconst org-ocr-drawer--easyocr-script "#!/usr/bin/env python3
import sys
import easyocr
import warnings
import contextlib

warnings.filterwarnings('ignore')

@contextlib.contextmanager
def suppress_stderr():
    import os
    import sys
    with open(os.devnull, 'w') as devnull:
        old_stderr = sys.stderr
        sys.stderr = devnull
        try:
            yield
        finally:
            sys.stderr = old_stderr

if len(sys.argv) != 3:
    print('Usage: easyocr-cli image.jpg output.txt', file=sys.stderr)
    sys.exit(1)

print('[EasyOCR] Starting...')
with suppress_stderr():
    reader = easyocr.Reader(['en'], gpu=False)
    print('[EasyOCR] Recognizing...')
    results = reader.readtext(sys.argv[1])

with open(sys.argv[2], 'w') as out:
    for _, text, _ in results:
        print(text, file=out)",
  "Python script that serves as a CLI for EasyOCR, writing output to a temp file.")

(defun org-ocr-drawer--install-easyocr-cli ()
  "Install the easyocr-cli Python script in `org-ocr-drawer-easyocr-script-dir`."
  (interactive)
  (let* ((script-name "easyocr-cli")
         (dir (expand-file-name org-ocr-drawer-easyocr-script-dir))
         (script-path (expand-file-name script-name dir)))
    (unless (file-exists-p script-path)
      (make-directory dir t)
      (with-temp-file script-path
        (insert org-ocr-drawer--easyocr-script))
      (set-file-modes script-path #o755)
      (message "Installed easyocr-cli at %s" script-path))
    script-path))

(defun org-ocr-drawer--run-ocr (image-path)
  "Run OCR on IMAGE-PATH using the configured backend. Return OCR text from file."
  (pcase org-ocr-drawer-backend
    ('tesseract
     (message "[Tesseract] Running OCR...")
     (shell-command-to-string
      (format "tesseract %s - -l eng"
              (shell-quote-argument image-path))))
    ('easyocr
     (let* ((cli-path (or (executable-find org-ocr-drawer-easyocr-cmd)
                          (org-ocr-drawer--install-easyocr-cli)))
            (cmd (if org-ocr-drawer-easyocr-conda-env
                     (format "conda run -n %s %s" org-ocr-drawer-easyocr-conda-env cli-path)
                   cli-path))
            (output-file (make-temp-file "easyocr-output" nil ".txt"))
            (full-cmd (format "%s %s %s"
                              cmd
                              (shell-quote-argument image-path)
                              (shell-quote-argument output-file))))
       (message "[EasyOCR] Running: %s" full-cmd)
       (shell-command full-cmd)
       (message "[EasyOCR] Done")
       (with-temp-buffer
         (insert-file-contents output-file)
         (buffer-string))))
    (_ (error "Unsupported OCR backend: %s" org-ocr-drawer-backend))))

(defun org-ocr-drawer--insert (image-path)
  "Insert an :ocr: drawer with OCR text using selected backend."
  (let ((full-path (expand-file-name image-path)))
    (when (file-exists-p full-path)
      (let ((ocr-text (org-ocr-drawer--run-ocr full-path)))
        (save-excursion
          (forward-line)
          (insert (format ":ocr:\n%s:end:\n" ocr-text))
          (org-cycle-hide-drawers 'all))))))

(defun org-ocr-drawer--after-insert-link (&rest args)
  "Advice for `org-download-insert-link` to add OCR drawer after inserting image."
  (let ((image-path (nth 1 args)))
    (when (and image-path (stringp image-path))
      (org-ocr-drawer--insert image-path))))

;;;###autoload
(defun org-ocr-drawer-enable ()
  "Enable automatic OCR drawer insertion after org-download clipboard image insertion."
  (interactive)
  (advice-add 'org-download-insert-link :after #'org-ocr-drawer--after-insert-link))

;;;###autoload
(defun org-ocr-drawer-disable ()
  "Disable automatic OCR drawer insertion."
  (interactive)
  (advice-remove 'org-download-insert-link #'org-ocr-drawer--after-insert-link))

(provide 'org-ocr-drawer)

;;; org-ocr-drawer.el ends her
