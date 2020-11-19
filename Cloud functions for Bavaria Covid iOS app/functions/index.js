const functions = require('firebase-functions');
const https = require('https');
// const fetch = require("node-fetch");
const admin = require('firebase-admin');
admin.initializeApp();
// TODO - Move this into a config file
const baseUrl = 'https://services7.arcgis.com/mOBPykOjAyBO2ZKk/arcgis/rest/services/RKI_Landkreisdaten/FeatureServer/0/query?where=1%3D1&outFields=cases7_per_100k&geometryType=esriGeometryPoint&inSR=4326&spatialRel=esriSpatialRelIntersects&returnGeometry=false&outSR=4326&f=json'

exports.calculateCovidStatus = functions.https.onCall(async (data, context) => {

  // Message text passed from the client.
  const text = data.lat;
  // console.log(text);

  const response = await doRequest(data.lat, data.lon)

  if (!response.features || !response.features.length > 0){
    return { text: "back response: no data found"  }
  }

    const cases7_per_100k = response.features[0].attributes.cases7_per_100k
    // console.log('cases - ' + cases7_per_100k)
    const covidStatus = calculateCovidStatus(cases7_per_100k)

    var language = data.language
    if (!language || !supportedLanguages.includes(language)){
      language = supportedLanguages[0]
    }
    // get message for the client from the Firestore DB.
    const documentFromDB = await admin.firestore().collection(language).doc(covidStatus.code).get()
    if (!documentFromDB.exists) {
        console.log('No such document!');
        return {
          text: "back response. Instruction message not found." 
        }
      } 
        // console.log(documentFromDB.data());
        const cases = Math.fround(cases7_per_100k);
  const resultData = {
    // // returning result to the client.
    message: documentFromDB.data().message, statusCode: covidStatus.code, color: covidStatus.color, cases: cases
  }

  // console.log(resultData)
  return resultData;


});

// this corresponds to Firestore DB branches. Another way is to check if corresponding branch exists or choose the default one.
//  TODO - move this into a config file
const supportedLanguages = ['en', 'de', 'ro']

// Covid status stages. Code corresponds to Firestore message branch.
//  TODO - move this into a config file
const green = { limit: 35, code: 'green', color: '#008000' };
const yellow = { limit: 50, code: 'yellow', color: '#FFFF00' };
const red = { limit: 100, code: 'red', color: '#FF0000' };
const darkRed = { limit: 100000, code: 'darkRed', color: '#8B0000' };

const statusStages = [green, yellow, red, darkRed]

function calculateCovidStatus(cases) {
  // statusStages.forEach..
  if (cases < statusStages[0].limit) {
    return statusStages[0];
  } else if (cases < statusStages[1].limit) {
    return statusStages[1];
  } else if (cases < statusStages[2].limit) {
    return statusStages[2];
  } else return statusStages[3];
}

async function doRequest(lat, lon) {
  const url = baseUrl  
  // + '&geometry=' + '12' + '%2C' + '52';   // for test
  + '&geometry=' + lon + '%2C' + lat;

  let promise = new Promise((resolve, reject) => {

    const options = new URL(url)

    var req = https.request(options, (res) => {
      res.setEncoding('utf8');
      var body = '';

      res.on('data', (chunk) => {
        body = body + chunk;
      });

      res.on('end', () => {
        console.log("Body :" + body);
        resolve(JSON.parse(body))

        if (res.statusCode !== 200) {
          console.log("Api call failed with response code " + res.statusCode);
        }
      });

    });
    req.on('error', (e) => {
      console.log('problem with request: ' + e.message);
      reject(e.message)
    });

    // write data to request body
    req.write('data\n');
    req.end();

  });

  return promise;

}