const NodeMediaServer = require('node-media-server');
const fs = require('fs');

// directory path
const dir = '/home/pi/nms/mediaroot/live';

// delete directory recursively
fs.rmdir(dir, { recursive: true }, (err) => {
    if (err) {
        console.log(`ERROR TRYING TO DELETE ${dir}`)
        console.log(err);
        //throw err;
    }

    console.log(`${dir} is deleted!`);

fs.mkdir(dir, (err) => {
    if (err) {
        console.log(`ERROR TRYING TO CREATE ${dir}`)
        console.log(err);
        //throw err;
    }

    console.log(`${dir} has been created!`);

	const config = {
			logType: 3, // 3 - Log everything (debug)
			rtmp: {
					port: 1935,
					chunk_size: 60000,
					gop_cache: true,
					ping: 60,
					ping_timeout: 30
			},
			http: {
					port: 8000,
					mediaroot: '/home/pi/nms/mediaroot',
					allow_origin: '*'
			},
			relay: {
					ffmpeg: '/usr/bin/ffmpeg',
					tasks: [
							{
									app: 'live',
									mode: 'static',
									edge: 'rtmp://192.168.1.77:1935/bcs/channel0_ext.bcs?channel=0&stream=0&user=admin&password=Havea6and3',
									name: 'foxcam',
									rtsp_transport : ['udp', 'tcp', 'udp_multicast', 'http']
							}
					]
			},
			trans: {
				ffmpeg: '/usr/bin/ffmpeg',
				tasks: [
					{
						app: 'live',
						hls: true,
						hlsFlags: '[hls_time=2:hls_list_size=3:hls_flags=delete_segments]',
						dash: true,
						dashFlags: '[f=dash:window_size=3:extra_window_size=5]'
					}
				]
			}
	};

	var nms = new NodeMediaServer(config)
	nms.run();


});
});