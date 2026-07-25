// // backend/middleware/upload.js
// const multer = require("multer");
// const path = require("path");
// const fs = require("fs");

// // Directory where customer images will be stored (served statically as /uploads/customers)
// const UPLOAD_DIR = path.join(__dirname, "..", "uploads", "customers");

// // Ensure the upload directory exists (multer will NOT create it for you)
// if (!fs.existsSync(UPLOAD_DIR)) {
//   fs.mkdirSync(UPLOAD_DIR, { recursive: true });
// }

// // ---- Storage engine ----
// const storage = multer.diskStorage({
//   destination: (req, file, cb) => {
//     cb(null, UPLOAD_DIR);
//   },
//   filename: (req, file, cb) => {
//     // e.g. goldImages-1731090000000-123456789.jpg
//     const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
//     const ext = path.extname(file.originalname).toLowerCase();
//     const safeFieldName = file.fieldname.replace(/[^a-zA-Z0-9_-]/g, "");
//     cb(null, `${safeFieldName}-${uniqueSuffix}${ext}`);
//   },
// });

// // ---- Only allow image files ----
// const ALLOWED_MIME_TYPES = [
//   "image/jpeg",
//   "image/jpg",
//   "image/png",
//   "image/webp",
//   "image/gif",
// ];

// const fileFilter = (req, file, cb) => {
//   if (ALLOWED_MIME_TYPES.includes(file.mimetype)) {
//     cb(null, true);
//   } else {
//     cb(new Error(`Invalid file type: ${file.mimetype}. Only image files are allowed.`), false);
//   }
// };

// // ---- Multer instance ----
// // Exported directly (not wrapped) so routes can call upload.fields([...]) / upload.single(...) etc,
// // matching: const upload = require("../middleware/upload");
// const upload = multer({
//   storage,
//   fileFilter,
//   limits: {
//     fileSize: 5 * 1024 * 1024, // 5MB per file
//     files: 300, // total files across all fields, per request (routes use maxCount up to 100 per field x 3 fields)
//   },
// });

// // Optional: centralized error handler for multer errors (file too large, wrong type, etc.)
// // Attached as a property on `upload` so it can be required alongside it without changing
// // the existing `const upload = require("../middleware/upload")` usage in routes.
// upload.handleUploadErrors = (err, req, res, next) => {
//   if (err instanceof multer.MulterError) {
//     return res.status(400).json({
//       success: false,
//       message: `Upload error: ${err.message}`,
//     });
//   } else if (err) {
//     return res.status(400).json({
//       success: false,
//       message: err.message || "File upload failed",
//     });
//   }
//   next();
// };

// module.exports = upload;


// backend/middleware/upload.js
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const sharp = require("sharp");

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

// ---- Compress/resize images after multer saves them to disk ----
// Runs AFTER handleUploadErrors so it only touches files that were
// successfully uploaded. GIFs are skipped (sharp would kill animation);
// everything else is resized (max 1280px side) and re-encoded.
// Attached as a property on `upload`, same pattern as handleUploadErrors,
// so routes can require it via: const upload = require("../middleware/upload");
upload.compressImages = async (req, res, next) => {
  if (!req.files) return next();

  try {
    const allFiles = Object.values(req.files).flat();

    await Promise.all(
      allFiles.map(async (file) => {
        // Skip GIFs — sharp would flatten them to a single static frame
        if (file.mimetype === "image/gif") return;

        const tempPath = `${file.path}_compressed`;

        await sharp(file.path)
          .rotate() // auto-orient based on EXIF, then strip EXIF
          .resize(1280, 1280, {
            fit: "inside",
            withoutEnlargement: true,
          })
          .jpeg({ quality: 70 })
          .toFile(tempPath);

        // Replace the original file with the compressed one
        fs.unlinkSync(file.path);
        fs.renameSync(tempPath, file.path);
      })
    );

    next();
  } catch (err) {
    console.error("❌ Image compression error:", err);
    // Don't block the upload if compression fails — just proceed with
    // the original, uncompressed files rather than losing the customer's data.
    next();
  }
};

module.exports = upload;