const mongoose = require("mongoose");

const employeeSchema = new mongoose.Schema(
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
    phone:{
        type:String,
        required:true,
        unique:true
    },
    department:String,
    position:String,

    // Employee kis branch mein kaam karta hai - required hai
    branch:{
        type:String,
        required:true,
        trim:true
    },

    salary:Number,

    // OTP login ke liye (temporary fields, verify hone ke baad clear ho jaate hain)
    otp:{
        type:String,
        select:false
    },
    otpExpiry:{
        type:Date,
        select:false
    }
},
{
    timestamps:true
});

module.exports = mongoose.model("Employee",employeeSchema);