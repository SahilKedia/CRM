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

    role:{
        type:String,
        required:true,
        enum:["admin"],
        default:"admin"
    },

    // Agar branch set hai to ye "branch admin" hai (sirf apni branch dekh payega).
    // Agar branch empty/blank hai to ye "super admin" hai (saari branches dekh payega).
    branch:{
        type:String,
        trim:true,
        default:null
    }

},
{timestamps:true}
);

module.exports = mongoose.model("User",userSchema);