const mongoose = require("mongoose");

const userSchema = new mongoose.Schema(
{
    name:{
        type:String,
        required:true
    },

    email:{
        type:String,
        required:true,
        unique:true
    },

    password:{
        type:String,
        required:true
    },

   role: {
  type: String,
  enum: ["superadmin", "admin", "employee"],
  default: "admin",
},

    // Agar branch set hai to ye "branch admin" hai (sirf apni branch dekh payega).
    // Agar branch empty/blank hai to ye "super admin" hai (saari branches dekh payega).
branch: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Branch",
    default: null,
    trim: true // ⚠️ ye ObjectId pe kaam nahi karega, hata dena
}
},
{timestamps:true}
);

module.exports = mongoose.model("User",userSchema);
