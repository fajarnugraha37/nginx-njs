IMAGE ?= nginx-njs-kit
NAME  ?= nginx-njs-kit
DOCKERFILE ?= Dockerfile
HTTP_PORT ?= 80
HTTPS_PORT ?= 443

.PHONY: build run stop logs reload test

build:
	@if docker images -q $(IMAGE) >/dev/null 2>&1; then \
		echo "image $(IMAGE) already exists, deleting."; \
		docker rmi -f $(IMAGE) >/dev/null 2>&1 || true; \
		docker images | grep $(IMAGE) && \
			echo "failed to delete old image $(IMAGE)" && exit 1 \
			|| echo "old image $(IMAGE) deleted."; \
		exit 0; \
	fi

	@echo "building image $(IMAGE)..."
	docker build \
		--tag $(IMAGE) \
		--progress=plain \
		--file=$(DOCKERFILE) .
	@if [ $$? -ne 0 ]; then \
		echo "failed to build image $(IMAGE)"; \
		exit 1; \
	else \
		echo "image $(IMAGE) built successfully"; \
	fi

start:
	@if docker ps -a | grep $(NAME) >/dev/null 2>&1; then \
		echo "container $(NAME) already exists, deleting."; \
		docker rm -f $(NAME) >/dev/null 2>&1 || true; \
		docker ps -a | grep $(NAME) && \
			echo "failed to delete old container $(NAME)" && exit 1 \
			|| echo "old container $(NAME) deleted."; \
	fi

	@echo "starting container $(NAME) from image $(IMAGE)..."
	docker run --name $(NAME) \
		--restart=unless-stopped -d \
	  	-e HMAC_SECRET=change-me \
	  	-e FF_PERCENT=50 \
	  	-v ./configs/nginx.conf:/etc/nginx/nginx.conf:ro \
	  	-v ./configs/conf.d:/etc/nginx/conf.d:ro \
	  	-v ./njs:/etc/nginx/njs:ro \
	  	-v ./html:/etc/nginx/html:ro \
	  	-v ./certs:/etc/nginx/certs:ro \
	 	-v ./log:/var/log/nginx \
		-p $(HTTP_PORT):80 \
		-p $(HTTPS_PORT):443 \
		$(IMAGE)
	@echo "up at http://localhost:$(HTTP_PORT) and https://localhost:$(HTTPS_PORT)"

stop:
	@echo "stopping container $(NAME)..."
	docker rm -f $(NAME) || true

clean:
	@echo "cleaning up, removing container $(NAME) and image $(IMAGE)..."
	docker rm -f $(NAME) >/dev/null 2>&1 || true
	@echo "removing image $(IMAGE)..."
	docker rmi -f $(IMAGE) >/dev/null 2>&1 || true
	@echo "removing logs..."
	rm -rf log/*

reload:
	@echo "reloading nginx in container $(NAME)..."
	docker exec $(NAME) nginx -t
	@echo "nginx config test passed, reloading..."
	docker exec $(NAME) nginx -s reload

ssh:
	@echo "opening shell into container $(NAME)..."
	docker exec -it $(NAME) /bin/bash
	
logs:
	@echo "tailing logs from container $(NAME)..."
	docker logs -f --tail=200 $(NAME)

test:
	@echo "running tests..."
	bash scripts/test.sh

ssl: 
	@if [ ! -d "certs" ]; then \
		echo "Directory certs does not exist. Creating..."; \
		mkdir -p certs; \
	else \
		echo "Directory certs already exists."; \
		rm -rf certs/*.crt; \
		rm -rf certs/*.key; \
		rm -rf certs/*.pem; \
	fi

	@echo "Creating SSL certificate configuration..."
	@echo "[req]" > certs/cert.conf
	@echo "default_bits = 2048" >> certs/cert.conf
	@echo "prompt = no" >> certs/cert.conf
	@echo "default_md = sha256" >> certs/cert.conf
	@echo "distinguished_name = dn" >> certs/cert.conf
	@echo "x509_extensions = v3_req" >> certs/cert.conf
	@echo "[dn]" >> certs/cert.conf
	@echo "C=US" >> certs/cert.conf
	@echo "ST=State" >> certs/cert.conf
	@echo "L=City" >> certs/cert.conf
	@echo "O=Organization" >> certs/cert.conf
	@echo "CN=localhost" >> certs/cert.conf
	@echo "[v3_req]" >> certs/cert.conf
	@echo "subjectAltName = @alt_names" >> certs/cert.conf
	@echo "[alt_names]" >> certs/cert.conf
	@echo "DNS.1 = localhost" >> certs/cert.conf

	@echo "Generating self-signed SSL certificate..."
	@openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout certs/cert.key \
		-out certs/cert.pem \
		-config certs/cert.conf \
		-extensions v3_req

	@echo "SSL Certificate Information:"
	openssl x509 -in certs/cert.pem -text -noout | grep -E "(Subject:|DNS:|Not Before|Not After)"; \
