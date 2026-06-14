window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === 'updateVehicle') {
        const vehicle = document.querySelector('.info.vehicle');

        if (data.status) {
            vehicle.classList.add('active');
            vehicle.classList.remove('inactive');

            document.getElementById('vehicle-speed').querySelector('span').textContent = data.speed;
            document.getElementById('vehicle-rpm').querySelector('span').textContent = data.rpm;
            document.getElementById('vehicle-gear').querySelector('span').textContent = data.gear;

            document.getElementById('fuel').querySelector('span').style.height = `${data.fuel}%`;
            document.getElementById('damage').querySelector('span').style.height = `${data.damage}%`;

            const seatbeltElement = document.getElementById('seatbelt');
            if (data.seatbelt.status) {
                seatbeltElement.classList.add('on');
            } else {
                seatbeltElement.classList.remove('on');
            }

            const lightsElement = document.getElementById('lights');
            lightsElement.className = `icon ${data.lights}`;

            const signalsElement = document.getElementById('signals');
            signalsElement.className = `icon ${data.signals}`;

            const speedCircle = document.querySelector('.info.vehicle #progress-speed svg circle.speed');
            speedCircle.style.strokeDashoffset = data.nail;

            const rpmCircle = document.querySelector('.info.vehicle #progress-rpm svg circle.rpm');
            rpmCircle.style.strokeDashoffset = data.rpmnail;
        } else {
            vehicle.classList.add('inactive');
            vehicle.classList.remove('active');
        }
    }
});
