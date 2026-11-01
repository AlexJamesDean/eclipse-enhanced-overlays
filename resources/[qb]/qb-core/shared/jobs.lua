QBCore.Shared.ForceJobDefaultDutyAtLogin = true -- true: use the job's defaultDuty value | false: restore the last saved duty state

QBCore.Shared.Jobs = {
    -- Public and casual employment
    unemployed = {
        label = 'Civilian',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Freelancer', payment = 10 },
        },
    },
    bus = {
        label = 'Transport Service',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Driver', payment = 50 },
        },
    },
    reporter = {
        label = 'Press Association',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Junior Reporter', payment = 50 },
        },
    },
    trucker = {
        label = 'Haulage',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Lorry Driver', payment = 50 },
        },
    },
    tow = {
        label = 'Vehicle Recovery',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Recovery Driver', payment = 50 },
        },
    },
    garbage = {
        label = 'Waste Management',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Collector', payment = 50 },
        },
    },
    vineyard = {
        label = 'Vineyard',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Picker', payment = 50 },
        },
    },
    hotdog = {
        label = 'Street Vendor',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Vendor', payment = 50 },
        },
    },

    -- Justice and emergency services
    judge = {
        label = 'Crown Court',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Magistrate', payment = 100 },
        },
    },
    lawyer = {
        label = 'Solicitor\'s Firm',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Junior Solicitor', payment = 50 },
        },
    },
    police = {
        label = 'Metropolitan Police Service',
        type = 'leo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Student Officer', payment = 50 },
            ['1'] = { name = 'Police Constable', payment = 75 },
            ['2'] = { name = 'Sergeant', payment = 100 },
            ['3'] = { name = 'Inspector', payment = 125 },
            ['4'] = { name = 'Superintendent', isboss = true, payment = 150 },
            ['5'] = { name = 'Commissioner', isboss = true, payment = 250 },
        },
    },
    ambulance = {
        label = 'London Ambulance Service',
        type = 'ems',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Student Paramedic', payment = 50 },
            ['1'] = { name = 'Paramedic', payment = 75 },
            ['2'] = { name = 'Senior Paramedic', payment = 100 },
            ['3'] = { name = 'Clinical Lead', payment = 125 },
            ['4'] = { name = 'Service Director', isboss = true, payment = 150 },
        },
    },

    -- Professional and commercial careers
    realestate = {
        label = 'Estate Agency',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Negotiator', payment = 50 },
            ['1'] = { name = 'Residential Agent', payment = 75 },
            ['2'] = { name = 'Commercial Agent', payment = 100 },
            ['3'] = { name = 'Senior Broker', payment = 125 },
            ['4'] = { name = 'Managing Partner', isboss = true, payment = 150 },
        },
    },
    taxi = {
        label = 'Private Hire',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Trainee Driver', payment = 50 },
            ['1'] = { name = 'Driver', payment = 75 },
            ['2'] = { name = 'Executive Driver', payment = 100 },
            ['3'] = { name = 'Senior Driver', payment = 125 },
            ['4'] = { name = 'Fleet Manager', isboss = true, payment = 150 },
        },
    },
    cardealer = {
        label = 'Motor Dealership',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Trainee Sales', payment = 50 },
            ['1'] = { name = 'Sales Executive', payment = 75 },
            ['2'] = { name = 'Senior Sales', payment = 100 },
            ['3'] = { name = 'Finance Specialist', payment = 125 },
            ['4'] = { name = 'Dealership Manager', isboss = true, payment = 150 },
        },
    },

    -- Vehicle workshops (internal IDs match their resource integrations)
    mechanic = {
        label = 'Auto Workshop',
        type = 'mechanic',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Apprentice', payment = 50 },
            ['1'] = { name = 'Technician', payment = 75 },
            ['2'] = { name = 'Senior Technician', payment = 100 },
            ['3'] = { name = 'Specialist', payment = 125 },
            ['4'] = { name = 'Workshop Manager', isboss = true, payment = 150 },
        },
    },
    mechanic2 = {
        label = 'Auto Workshop',
        type = 'mechanic',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Apprentice', payment = 50 },
            ['1'] = { name = 'Technician', payment = 75 },
            ['2'] = { name = 'Senior Technician', payment = 100 },
            ['3'] = { name = 'Specialist', payment = 125 },
            ['4'] = { name = 'Workshop Manager', isboss = true, payment = 150 },
        },
    },
    mechanic3 = {
        label = 'Auto Workshop',
        type = 'mechanic',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Apprentice', payment = 50 },
            ['1'] = { name = 'Technician', payment = 75 },
            ['2'] = { name = 'Senior Technician', payment = 100 },
            ['3'] = { name = 'Specialist', payment = 125 },
            ['4'] = { name = 'Workshop Manager', isboss = true, payment = 150 },
        },
    },
    beeker = {
        label = 'Motor Garage',
        type = 'mechanic',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Apprentice', payment = 50 },
            ['1'] = { name = 'Technician', payment = 75 },
            ['2'] = { name = 'Senior Technician', payment = 100 },
            ['3'] = { name = 'Specialist', payment = 125 },
            ['4'] = { name = 'Garage Manager', isboss = true, payment = 150 },
        },
    },
    bennys = {
        label = 'Custom Workshop',
        type = 'mechanic',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            ['0'] = { name = 'Apprentice', payment = 50 },
            ['1'] = { name = 'Technician', payment = 75 },
            ['2'] = { name = 'Senior Technician', payment = 100 },
            ['3'] = { name = 'Specialist', payment = 125 },
            ['4'] = { name = 'Workshop Manager', isboss = true, payment = 150 },
        },
    },
    government = {
        label = 'Government',
        defaultDuty = true,
        offDutyPay = true,
        grades = {
            ['0'] = { name = 'Trainee', payment = 200 },
            ['1'] = { name = 'Assistant', payment = 250 },
            ['2'] = { name = 'Advisor', payment = 300 },
            ['3'] = { name = 'Supervisor', payment = 400 },
            ['4'] = { name = 'MP', payment = 500 },
            ['5'] = { name = 'PM', isboss = true, payment = 0 },
        } 
    }
}
