function validateroll(name) {
	if( name.value == null ){
		alert("Please check the entered roll no.");
		name.focus();
		return false;
	}
	if ( name.value.match("15IT.*") == null ){
		alert("Please check the entered roll no.");
		name.focus();
	}
}

function validate(form){
	flag = validateroll(form.roll1);
	if ( flag == false){
		return;
	}
	return validateroll(form.roll2);
}
