# KYC (Know Your Customer) Screens

## Overview
The KYC flow is a 3-step process for user identity verification that occurs after account creation. Each step includes form validation, skip options, and progress tracking.

## Flow Diagram

```
Account Success Screen
    ↓ (Continue to Verify Account)
Step 1: Profile Information
    ↓ (Continue or Skip)
Step 2: Bank Information
    ↓ (Continue or Skip)
Step 3: Proof of Identity
    ↓ (Complete Setup or Skip)
Verifying Identity (60s auto-timer)
    ↓ (Auto-navigate after 60s)
All Set!
    ↓ (Continue to Dashboard)
Dashboard
```

## Screens

### 1. Profile Information Screen (Step 1 of 3)
**File**: `profile_information_screen.dart`

**Fields**:
- **Personal Information**:
  - First Name (required)
  - Last Name (required)
  - Email Address (required, email validation)
  - Phone Number (required)

- **Address Information**:
  - Address Line 1 (required)
  - Address Line 2 (optional)
  - City (required)
  - Postal Code (required)
  - State (required, dropdown)
  - Country (required, dropdown)

**Validation**:
- All required fields show red border + error message if empty
- Email must be valid format
- Errors clear on typing

**Actions**:
- **Skip**: Go to Step 2 without validation
- **Continue**: Validate and go to Step 2

---

### 2. Bank Information Screen (Step 2 of 3)
**File**: `bank_information_screen.dart`

**Fields**:
- BVN (11 digits, required)
- Date of Birth:
  - Day (dropdown, required)
  - Month (dropdown, required)
  - Year (dropdown, required)
- Gender (dropdown, required)

**Validation**:
- BVN must be exactly 11 digits
- All date fields required
- Gender required
- Red borders + error messages on validation failure

**Actions**:
- **Skip**: Go to Step 3 without validation
- **Continue**: Validate and go to Step 3

---

### 3. Proof of Identity Screen (Step 3 of 3)
**File**: `proof_of_identity_screen.dart`

**Fields**:
- **Identity Document**:
  - Select ID Type (dropdown: National ID, Driver's License, Passport, Voter's Card)
  - Enter ID Number (text input)

- **Document Expiry Date**:
  - Month (dropdown)
  - Day (dropdown)
  - Year (dropdown)

- **Upload ID**:
  - Dashed border container
  - Click to upload (PDF, JPEG, PNG)
  - Shows uploaded filename

**Important Notice Box**:
- Document must be clear and readable
- All corners visible
- Not older than 3 months
- Encrypted and secure storage

**Validation**:
- All fields required except document upload (shows error)
- Red borders on validation failure

**Actions**:
- **Skip**: Go to Verifying screen
- **Complete Setup**: Validate and go to Verifying screen

---

### 4. Verifying Identity Screen
**File**: `verifying_identity_screen.dart`

**Features**:
- **No user interaction** (no buttons)
- **60-second timer** with progress bar
- **Animated progress steps**:
  1. Verifying your identity (0-20s)
  2. Setting up your account (20-40s)
  3. Preparing your dashboard (40-60s)
- **Auto-navigation** to All Set screen after 60s
- Purple background with glows (like splash screen)
- Shield icon with "Verifying your identity" title

**UI Elements**:
- Large shield icon
- Progress steps with icons (shield, settings, dashboard)
- Active step highlighted with cyan background
- Gradient progress bar (cyan to orange)

---

### 5. All Set Screen
**File**: `all_set_screen.dart`

**Features**:
- Success confirmation after verification
- Purple background with glows
- Shield icon
- "All Set!" title
- "Your account has been created successfully"
- "Welcome to communal"
- Three completed steps (all with checkmarks)
- "Continue to Dashboard" button

**UI Elements**:
- Same purple background as verifying screen
- All steps show as completed (cyan circles with checkmarks)
- White button with black text

---

## Reusable Widgets Created

### 1. CustomTextField
**File**: `core/widgets/custom_text_field.dart`

**Features**:
- Label support
- Hint text
- Prefix/suffix icons
- Password visibility toggle
- **Red border on error**
- **Error text below field**
- Custom keyboard types
- Input formatters
- Max length

**Usage**:
```dart
CustomTextField(
  controller: _controller,
  labelText: 'Email',
  hintText: 'Enter email',
  errorText: _emailError,
  onChanged: (_) => clearErrors(),
)
```

---

### 2. PhoneInputField
**File**: `core/widgets/phone_input_field.dart`

**Features**:
- Country selector with flag 🇳🇬
- Phone number input (digits only)
- 11-digit max length
- Red border on error
- Error text below

**Usage**:
```dart
PhoneInputField(
  controller: _phoneController,
  errorText: _phoneError,
  onCountryTap: () { },
)
```

---

### 3. OtpInputField
**File**: `core/widgets/otp_input_field.dart`

**Features**:
- 6 individual input boxes
- Auto-focus next field
- Purple border when filled
- Auto-completion callback
- Numeric only

**Usage**:
```dart
OtpInputField(
  length: 6,
  onChanged: (code) { },
  onCompleted: (code) { },
)
```

---

### 4. AppSecondaryButton (Updated)
**File**: `core/widgets/app_elevated_button.dart`

**New Feature**: `isDark` parameter
- `isDark: true` (default) - White border, white text (for dark backgrounds)
- `isDark: false` - Gray border, black text (for light backgrounds)

**Usage**:
```dart
// On dark background (Welcome screen)
AppSecondaryButton(
  title: 'Sign in',
  onPressed: () { },
)

// On light background (KYC screens)
AppSecondaryButton(
  title: 'Skip',
  isDark: false,
  onPressed: () { },
)
```

---

## Validation Rules

### Profile Information
- First Name: Required
- Last Name: Required
- Email: Required, valid email format
- Phone: Required
- Address Line 1: Required
- City: Required
- Postal Code: Required
- State: Required
- Country: Required

### Bank Information
- BVN: Required, exactly 11 digits
- Date of Birth: All fields required (day, month, year)
- Gender: Required

### Proof of Identity
- ID Type: Required
- ID Number: Required
- Expiry Date: All fields required (month, day, year)
- Document Upload: Required (shows error if not uploaded)

---

## Routes

All KYC routes are prefixed with `/kyc/`:

```dart
/kyc/profile-info       → Profile Information (Step 1)
/kyc/bank-info          → Bank Information (Step 2)
/kyc/proof-of-identity  → Proof of Identity (Step 3)
/kyc/verifying          → Verifying Identity (60s timer)
/kyc/all-set            → All Set! (Success)
```

---

## Design Elements

### Colors
- **Purple**: `#742CE7` (primary color)
- **Cyan/Teal**: `#00D9FF` (progress, active states)
- **Red**: Validation errors
- **Gray**: Borders, placeholder text
- **White**: Text on purple backgrounds

### Typography
- **Title**: 24-28sp, bold (w700)
- **Subtitle**: 14sp, regular (w400)
- **Body**: 16sp
- **Error**: 12sp, red
- **Footer**: 11sp

### Progress Bar
- Shows fraction completion (1/3, 2/3, 3/3)
- Purple color
- 4h height
- Shows step label and "Step X of 3"

### Buttons
- **Primary**: Purple, rounded (25r)
- **Secondary (Light BG)**: Gray border, black text
- **Secondary (Dark BG)**: White border, white text
- Both: 50h height, full width

---

## File Structure

```
mobile/lib/screens/
├── kyc/
│   ├── profile_information_screen.dart
│   ├── bank_information_screen.dart
│   ├── proof_of_identity_screen.dart
│   ├── verifying_identity_screen.dart
│   ├── all_set_screen.dart
│   └── README.md
└── auth/
    ├── signup_screen.dart (updated)
    └── account_success_screen.dart (updated)
```

---

## Technical Implementation

### Dropdown Pattern
```dart
_buildDropdown(
  label: 'Select',
  value: _selectedValue,
  items: ['Item 1', 'Item 2'],
  onChanged: (value) {
    setState(() {
      _selectedValue = value;
      _error = null;
    });
  },
  errorText: _error,
)
```

### Validation Pattern
```dart
bool _validateForm() {
  _clearErrors();
  bool isValid = true;

  if (_controller.text.isEmpty) {
    setState(() {
      _error = 'Field is required';
    });
    isValid = false;
  }

  return isValid;
}
```

### Timer Pattern (Verifying Screen)
```dart
Timer.periodic(Duration(milliseconds: 100), (timer) {
  // Update progress
  setState(() { _progress += 0.00167; }); // ~60s total
  
  if (_progress >= 1.0) {
    timer.cancel();
    context.pushReplacement('/kyc/all-set');
  }
});
```

---

## Next Steps / TODO

- [ ] Add actual file picker for document upload
- [ ] Implement country selector dialog
- [ ] Add Terms & Conditions screen
- [ ] Add Privacy Policy screen
- [ ] Implement actual BVN verification API
- [ ] Implement NIN/BVN verification after All Set
- [ ] Add dashboard screen
- [ ] Persist KYC data locally/remotely

---

## Testing

To test the full KYC flow:
1. Go to Welcome Screen
2. Click "Create an account"
3. Enter phone number → Sign up
4. Verify phone (OTP)
5. Set PIN or Password
6. Account Success → Continue to Verify
7. Fill Profile Information (Step 1) → Continue/Skip
8. Fill Bank Information (Step 2) → Continue/Skip
9. Fill Proof of Identity (Step 3) → Complete Setup/Skip
10. Watch Verifying screen (60s)
11. All Set! → Continue to Dashboard


