var TEMP_19 = flow.get("TEMP_19"); //attic
var HUM_19 = flow.get("HUM_19"); //attic

var TEMP_21 = flow.get("TEMP_21"); //closet floor
var HUM_21 = flow.get("HUM_21"); //closet floor

var TEMP_22 = flow.get("TEMP_22"); //closet 
var HUM_22 = flow.get("HUM_22"); //closet 

var LIGHT_22 = flow.get("LIGHT_22"); //closet light on/off

var SILENT_NIGHT = flow.get("SILENT_NIGHT"); //silent night on/off

msg.payload = `attic -> TEMP_19=${TEMP_19}, HUM_19=${HUM_19},  floor -> TEMP_21=${TEMP_21}, HUM_21=${HUM_21}, closet -> TEMP_22=${TEMP_22}, HUM_22=${HUM_22},  LIGHT_22=${LIGHT_22}`;


if (LIGHT_22 === "off" && SILENT_NIGHT === "on") {
	return [null, null, null, msg];
}

//IF LIGHTS OFF AND TOO COLD IN ATTIC  - USE CLOSET FLOOR
const tooColdInAttic = (TEMP_19 < 65.5 && TEMP_22 < 67.0 && TEMP_19 < TEMP_21);
if (LIGHT_22 === "off" && tooColdInAttic) {
    return [null, msg, null, null];
}


//IF LIGHTS ON AND TOO HUMID IN ATTIC - USE CLOSET FLOOR
//  CLOSET LIGHTS ON AN OVER 65% HUM - ATTICK ABOVE 65% AND HIGHER HUM THAN FLOOR
const tooHumidInAtticAndLightsOn = (LIGHT_22 === "on" && HUM_22 > 65.0 && HUM_19 > 65.0 && HUM_19 > HUM_21);
if (tooHumidInAtticAndLightsOn) {
    return [null, msg, null, null];
}

//IF LIGHTS OFF AND TOO HUMID IN ATTIC - USE CLOSET FLOOR
//  CLOSET LIGHTS ON AN OVER 55% HUM - ATTICK ABOVE 55% AND HIGHER HUM THAN FLOOR
const tooHumidInAtticAndLightsOff = (LIGHT_22 === "off" && HUM_22 > 55.0 && HUM_19 > 55.0 && HUM_19 > HUM_21);
if (tooHumidInAtticAndLightsOff) {
    return [null, msg, null, null];
}


//IF TOO HOT IN CL THEN TURN ON BOTH INTAKES
if (TEMP_22 > 82.9 && TEMP_19 < 75.0 && TEMP_21 < 75.0) {
    return [null, null, msg, null];
}


//IF ATTICK is BELOW 73.1 OR ATTICK TEMP IS BELOW FLOOR (or close enough)
const attickIsColderEnough = ((TEMP_19 - TEMP_21) < 6.0); //that attic less than 6 deg warmer than floor
if (TEMP_19 < 73.1 || attickIsColderEnough) {
    return [msg, null, null, null];
} else {
    return [null, msg, null, null];
}