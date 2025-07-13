TRAVEL_POLICIES = [
    {
        "category": "Air Travel",
        "policy": (
            "Air travel is permitted only for employees with grade 'Management Executive'. "
            "Travel must be pre-approved (approval_status: true) and booked through an approved travel agent (booking_method: Corporate Portal). "
            "Business and First Class are not permitted regardless of duration (mode_of_transport). "
            "Travel must follow Lowest Fare Routing (LFR) and be booked at least 14 days in advance (days_in_advance ≥ 14). "
            "All used tickets must be submitted as receipts (receipt_attached: true)."
        )
    },
    {
        "category": "Accommodation",
        "policy": (
            "Hotel reimbursement caps depend on employee_grade and city_tier:\n"
            "- Management Executive: ₹3000 (Tier 1), ₹2000 (Tier 2), ₹1800 (Tier 3)\n"
            "- Executive/Faculty: ₹1500, ₹1200, ₹850\n"
            "- Non-Executive: ₹1200, ₹1000, ₹750\n"
            "Booking must be via approved platforms (booking_method) or explicitly approved. Receipts are mandatory (receipt_attached: true)."
        )
    },
    {
        "category": "Meals",
        "policy": (
            "Daily food allowance is ₹500 for Tier 1 cities, ₹400 for Tier 2 and 3 (city_tier). "
            "Maximum of 3 tea/coffee breaks per day. All expenses must have itemized receipts (receipt_attached: true). "
            "Fine dining or excessive claims require pre-approval (approval_status: true)."
        )
    },
    {
        "category": "Transportation",
        "policy": (
            "Taxi, auto-rickshaw, or shared cabs are preferred for local travel. "
            "Car rentals are allowed only when public transport is impractical and must be pre-approved (approval_status: true). "
            "Receipts are required and must include travel details (receipt_attached: true)."
        )
    },
    {
        "category": "Personal Vehicle Reimbursement",
        "policy": (
            "Employees using personal vehicles may claim:\n"
            "- ₹7/km for four-wheelers\n"
            "- ₹2.5/km for two-wheelers\n"
            "mode_of_transport must be declared. justification_text and a travel log with distance, date, and purpose are required. "
            "Receipts must be attached (receipt_attached: true)."
        )
    },
    {
        "category": "Rail Travel",
        "policy": (
            "Employees with grade 'Executive/Faculty' are eligible for AC 3-Tier for overnight travel. "
            "AC 2-Tier is permitted only if AC 3-Tier is unavailable and with prior approval (approval_status: true). "
            "For short daytime journeys, Non-AC Chair Car is preferred. "
            "Non-executive staff are allowed Sleeper Class only. Receipts must be attached (receipt_attached: true)."
        )
    },
    {
        "category": "Grade Entitlement",
        "policy": (
            "All travel entitlements (mode, lodging, meals) depend on employee_grade:\n"
            "- Management Executives can access higher limits and AC travel.\n"
            "- Non-Executives are limited to sleeper class, basic lodging, and capped meals.\n"
            "These overrides take precedence over default category limits."
        )
    },
    {
        "category": "City Category Allowance",
        "policy": (
            "Cities must be classified (city_tier) as Tier 1, 2, or 3. "
            "This affects reimbursement ceilings for accommodation, meals, and day stays. "
            "Refer to the official city-tier list to classify city appropriately."
        )
    },
    {
        "category": "Tour vs Deputation",
        "policy": (
            "Trips ≤15 days (travel_duration_days ≤ 15) are classified as 'Tour' and require actual bills. "
            "Trips >15 days are 'Deputation' and are reimbursed using fixed allowances from Day 8 onward. "
            "Pre-classification and approval (approval_status: true) are required."
        )
    },
    {
        "category": "Late Bill Submission",
        "policy": (
            "Bills must be submitted the next working day after return. "
            "Claims submitted after 30 days must include written justification (justification_text) and HOD approval (approval_status: true) "
            "or they may be rejected or deducted."
        )
    },
    {
        "category": "Booking Process and Approval",
        "policy": (
            "All bookings (booking_method) must be made through approved travel agents and routed via the Accounts Department. "
            "approval_status must be true for all bookings. Exceptions require documentation (justification_text)."
        )
    },
    {
        "category": "Cash Advances",
        "policy": (
            "Cash advances are only granted if there are no pending unsettled advances. "
            "A Tour Budget Plan must be submitted at least 2 days before travel. "
            "approval_status: true and documentation are required."
        )
    },
    {
        "category": "Day Stay",
        "policy": (
            "If the waiting time between connections exceeds 4 hours, employees are eligible for day stay reimbursement. "
            "Rates: ₹1000 (Tier 1), ₹800 (Tier 2), ₹600 (Tier 3). "
            "travel_duration_days and city_tier must be provided. Receipts (receipt_attached: true) and justification are required."
        )
    },
    {
        "category": "Compliance Failure",
        "policy": (
            "If travel is missed due to personal negligence (e.g., missed train/flight), the rebooking must be at personal cost. "
            "Emergencies may be reimbursed with justification (justification_text) and HOD approval (approval_status: true)."
        )
    },
    {
        "category": "Non-Reimbursable Expenses",
        "policy": (
            "The following are never reimbursed regardless of claim: personal entertainment, in-flight purchases, hotel tips, club memberships, "
            "and porter charges (unless for institutional equipment)."
        )
    },
    {
        "category": "Receipts and Approvals",
        "policy": (
            "All claims must include valid, original receipts (receipt_attached: true). "
            "Receipts must show vendor, date, amount, and payment method. "
            "Missing receipts or exceptions require justification (justification_text) and prior approval (approval_status: true)."
        )
    },
    {
        "category": "Local/Suburban Travel",
        "policy": (
            "Local/suburban travel (within 100 km of HQ) follows actual expense reimbursement. "
            "mode_of_transport, amount, and receipts (receipt_attached: true) are required. "
            "Approval is needed (approval_status) for taxis or personal vehicle use."
        )
    }
]