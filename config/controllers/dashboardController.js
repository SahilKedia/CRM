const Employee = require("../models/Employee");
const Customer = require("../models/Customer");

exports.dashboard = async (req, res) => {

    try {

        const totalEmployees = await Employee.countDocuments();

        const totalCustomers = await Customer.countDocuments();

        const recentCustomers = await Customer.find()
            .sort({ createdAt: -1 })
            .limit(5);

        res.json({

            success: true,

            data: {

                totalEmployees,

                totalCustomers,

                totalBranches: 5,

                revenue: 45200,

                recentCustomers

            }

        });

    } catch (err) {

        res.status(500).json({

            success: false,

            message: err.message

        });

    }

};