// backend/middleware/upload.js
const multer = require("multer");
const path = require("path");
const fs = require("fs");

// Directory where customer images will be stored (served statically as /uploads/customers)
const UPLOAD_DIR = path.join(__dirname, "..", "uploads", "customers");

// Ensure the upload directory exists (multer will NOT create it for you)
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

// ---- Storage engine ----
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, UPLOAD_DIR);
  },
  filename: (req, file, cb) => {
    // e.g. goldImages-1731090000000-123456789.jpg
    const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    const ext = path.extname(file.originalname).toLowerCase();
    const safeFieldName = file.fieldname.replace(/[^a-zA-Z0-9_-]/g, "");
    cb(null, `${safeFieldName}-${uniqueSuffix}${ext}`);
  },
});

// ---- Only allow image files ----
const ALLOWED_MIME_TYPES = [
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/webp",
  "image/gif",
];

const fileFilter = (req, file, cb) => {
  if (ALLOWED_MIME_TYPES.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error(`Invalid file type: ${file.mimetype}. Only image files are allowed.`), false);
  }
};

// ---- Multer instance ----
// Exported directly (not wrapped) so routes can call upload.fields([...]) / upload.single(...) etc,
// matching: const upload = require("../middleware/upload");
const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB per file
    files: 300, // total files across all fields, per request (routes use maxCount up to 100 per field x 3 fields)
  },
});

// Optional: centralized error handler for multer errors (file too large, wrong type, etc.)
// Attached as a property on `upload` so it can be required alongside it without changing
// the existing `const upload = require("../middleware/upload")` usage in routes.
upload.handleUploadErrors = (err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    return res.status(400).json({
      success: false,
      message: `Upload error: ${err.message}`,
    });
  } else if (err) {
    return res.status(400).json({
      success: false,
      message: err.message || "File upload failed",
    });
  }
  next();
};

module.exports = upload;