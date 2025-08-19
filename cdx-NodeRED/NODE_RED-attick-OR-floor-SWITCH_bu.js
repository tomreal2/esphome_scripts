var TEMP_19 = flow.get("TEMP_19"); //attic
var HUM_19 = flow.get("HUM_19"); //attic

var TEMP_21 = flow.get("TEMP_21"); //closet floor
var HUM_21 = flow.get("HUM_21"); //closet floor

var TEMP_22 = flow.get("TEMP_22"); //closet 
var HUM_22 = flow.get("HUM_22"); //closet 

var LIGHT_22 = flow.get("LIGHT_22"); //closet light on/off


msg.payload = `attic -> TEMP_19=${TEMP_19}, HUM_19=${HUM_19},  floor -> TEMP_21=${TEMP_21}, HUM_21=${HUM_21}, closet -> TEMP_22=${TEMP_22}, HUM_22=${HUM_22},  LIGHT_22=${LIGHT_22}`;


//IF LIGHTS OFF AND TOO COLD IN ATTIC  - USE CLOSET FLOOR
const tooColdInAttic = (TEMP_19 < 65.5 && TEMP_22 < 67.0 && TEMP_19 < TEMP_21);
if (LIGHT_22 === "off" && tooColdInAttic) {
    return [null, msg, null];
}


//IF LIGHTS OFF AND 
// ATTIC TEMP IS WITHIN RANGE AND (ATTIC HUM LOWER THAN CLOSET OR LOWER THAN FLOOR)  - USE ATTIC
const atticInRange = (TEMP_19 < 82.0 && (HUM_19 < HUM_22 || HUM_19 <= HUM_21 || HUM_19 <= 50.0));
if (LIGHT_22 === "off" && atticInRange) {
    return [msg, null, null];
}


//IF TOO HUMID IN ATTIC - USE CLOSET FLOOR
//	if attic over 50 and floor lower than attic // removed HUM_22 > 50.0 (closet) requirement
const tooHumidInAttic = (HUM_19 > 50.0 && HUM_19 > HUM_21);
if (tooHumidInAttic) {
    return [null, msg, null];
}


//IF TOO HOT IN CL THEN TURN ON BOTH INTAKES
if (TEMP_22 > 82.9 && TEMP_19 < 74.0 && TEMP_21 < 74.0) {
    return [null, null, msg];
}


//IF ATTICK is BELOW 73.1 OR ATTICK TEMP IS BELOW FLOOR
if (TEMP_19 < 73.1 || TEMP_19 < TEMP_21) {
    return [msg, null, null];
} else {
    return [null, msg, null];
}