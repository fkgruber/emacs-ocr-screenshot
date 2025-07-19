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
;; :ocr: drawer under the image link containing the Tesseract OCR output,
;; and folds the drawer automatically.
;;
;; To use:
;;
;; (require 'org-ocr-drawer)
;; (org-ocr-drawer-enable)
;;
;; Make sure you have Tesseract OCR installed (`brew install tesseract` on macOS).

;;; Code:

(require 'org)
(require 'org-download)

(defun org-ocr-drawer--insert (image-path)
  "Insert an :ocr: drawer with Tesseract OCR text under the Org image link."
  (let ((full-path (expand-file-name image-path)))
    (when (file-exists-p full-path)
      (let ((ocr-text (shell-command-to-string
                       (format "tesseract %s - -l eng"
                               (shell-quote-argument full-path)))))
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

;;; org-ocr-drawer.el ends here
