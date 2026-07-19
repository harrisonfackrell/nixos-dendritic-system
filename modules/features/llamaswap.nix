{ self, inputs, ... }:
{
  flake.nixosModules.llamaswap = { config, pkgs, lib, ... }:
    {
      services.llama-swap = {
        enable = true;
        openFirewall = true;
        listenAddress = "0.0.0.0";
        port = 5001;
        settings = let
          llama-cpp = pkgs.llama-cpp-vulkan;
          llama-server = lib.getExe' llama-cpp "llama-server";
        in {
          healthCheckTimeout = 60;
          models = {
            # Roleplaying
            "MeroMero Sparse" = {
              cmd = "${llama-server} --no-ui -np 1 -kvu --port $\{PORT\} --fit on --cache-ram 0 --fit-target 0 --swa-full --jinja -m /etc/nixos/ai/models/text/meromero-26b-a4b-q6_K.gguf --mmproj /etc/nixos/ai/models/vision/gemma4-26b-a4b-mmproj.gguf";
              filters = {
                setParams = {
                  temperature = 1.0;
                  top_p = 0.95;
                  top_k = 64;
                  chat_template_kwargs = {
                    enable_thinking = false;
                  };
                };
                setParamsByID = {
                  "$\{MODEL_ID\} (Thinking)" = {
                    chat_template_kwargs = {
                      enable_thinking = true;
                    };
                  };
                  "$\{MODEL_ID\} (Instruct)" = {
                    chat_template_kwargs = {
                      enable_thinking = false;
                    };
                  };
                };
              };
            };
            "MeroMero Dense" = {
              cmd = "${llama-server} --no-ui -np 1 -kvu -b 8192 --port $\{PORT\} --fit-target 0 --cache-ram 0 --ctx-checkpoints 0 --jinja -m /etc/nixos/ai/models/text/meromero-31b-q6_K.gguf --mmproj /etc/nixos/ai/models/vision/gemma4-31b-mmproj.gguf";
              filters = {
                setParams = {
                  temperature = 1.0;
                  top_p = 0.95;
                  top_k = 64;
                  chat_template_kwargs = {
                    enable_thinking = true;
                  };
                };
                setParamsByID = {
                  "$\{MODEL_ID\} (Thinking)" = {
                    chat_template_kwargs = {
                      enable_thinking = true;
                    };
                  };
                  "$\{MODEL_ID\} (Instruct)" = {
                    chat_template_kwargs = {
                      enable_thinking = false;
                    };
                  };
                };
              };
            };
            # General Productivity
            "Gemma4 Sparse" = {
              cmd = "${llama-server} --no-ui -np 1 -kvu --port $\{PORT\} --fit-target 0 --cache-ram 0 --swa-full --jinja -m /etc/nixos/ai/models/text/gemma4-26b-a4b-q4_K_XL.gguf --mmproj /etc/nixos/ai/models/vision/gemma4-26b-a4b-mmproj.gguf --spec-type draft-mtp -md /etc/nixos/ai/models/draft/gemma4-26b-a4b.gguf";
              filters = {
                setParams = {
                  temperature = 1.0;
                  top_p = 0.95;
                  top_k = 64;
                  chat_template_kwargs = {
                    enable_thinking = false;
                  };
                };
                setParamsByID = {
                  "$\{MODEL_ID\} (Thinking)" = {
                    chat_template_kwargs = {
                      enable_thinking = true;
                    };
                  };
                  "$\{MODEL_ID\} (Instruct)" = {
                    chat_template_kwargs = {
                      enable_thinking = false;
                    };
                  };
                };
              };
            };
            "Gemma4 Dense" = {
              cmd = "${llama-server} --no-ui -np 1 -kvu --port $\{PORT\} --fit-target 0 --cache-ram 0 --swa-full --jinja -m /etc/nixos/ai/models/text/gemma4-31b-q4_K_XL.gguf --mmproj /etc/nixos/ai/models/vision/gemma4-31b-mmproj.gguf --spec-type draft-mtp -md /etc/nixos/ai/models/draft/gemma4-31b.gguf";
              filters = {
                setParams = {
                  temperature = 1.0;
                  top_p = 0.95;
                  top_k = 64;
                  chat_template_kwargs = {
                    enable_thinking = true;
                  };
                };
                setParamsByID = {
                  "$\{MODEL_ID\} (Thinking)" = {
                    chat_template_kwargs = {
                      enable_thinking = true;
                    };
                  };
                  "$\{MODEL_ID\} (Instruct)" = {
                    chat_template_kwargs = {
                      enable_thinking = false;
                    };
                  };
                };
              };
            };
            # Programming
            "Qwen3.6 Dense" = {
              cmd = "${llama-server} -lv 4 --no-ui -np 1 -kvu -ctxcp 16 --cache-ram 512 --port $\{PORT\} --fit-target 0 --jinja -m /etc/nixos/ai/models/text/qwopus3.6-27b-MTP-q6_K.gguf --spec-type draft-mtp";
              filters = {
                setParams = {
                  temperature = 0.6;
                  top_p = 0.95;
                  top_k = 20;
                  min_p = 0.0;
                  presence_penalty = 0.0;
                  repetition_penalty = 1.0;
                  chat_template_kwargs = {
                    enable_thinking = true;
                    preserve_thinking = true;
                  };
                };
                setParamsByID = {
                  "$\{MODEL_ID\} (Thinking)" = {
                    temperature = 1.0;
                    top_p = 0.95;
                    top_k = 20;
                    min_p = 0.0;
                    presence_penalty = 0.5;
                    repetition_penalty = 1.0;
                    chat_template_kwargs = {
                      enable_thinking = true;
                      preserve_thinking = true;
                    };
                  };
                  "$\{MODEL_ID\} (Instruct)" = {
                    temperature = 0.7;
                    top_p = 0.80;
                    top_k = 20;
                    min_p = 0.0;
                    presence_penalty = 1.5;
                    repetition_penalty = 1.0;
                    chat_template_kwargs = {
                      enable_thinking = false;
                    };
                  };
                };
              };
            };
            "Qwen3.6 Sparse" = {
              cmd = "${llama-server} --no-ui -np 1 -kvu -ctxcp 32 --cache-ram 256 --port $\{PORT\} --fit-target 0 --jinja -m /etc/nixos/ai/models/text/qwopus3.6-35b-a3b-MTP-q5_K_M.gguf --spec-type draft-mtp --spec-draft-n-max 2";
              filters = {
                setParams = {
                  temperature = 0.7;
                  top_p = 0.80;
                  top_k = 20;
                  min_p = 0.0;
                  presence_penalty = 1.5;
                  repetition_penalty = 1.0;
                  chat_template_kwargs = {
                    enable_thinking = false;
                  };
                };
                setParamsByID = {
                  "$\{MODEL_ID\} (Thinking)" = {
                    temperature = 1.0;
                    top_p = 0.95;
                    top_k = 20;
                    min_p = 0.0;
                    presence_penalty = 0.5;
                    repetition_penalty = 1.0;
                    chat_template_kwargs = {
                      enable_thinking = true;
                      preserve_thinking = true;
                    };
                  };
                  "$\{MODEL_ID\} (Instruct)" = {
                    temperature = 0.7;
                    top_p = 0.80;
                    top_k = 20;
                    min_p = 0.0;
                    presence_penalty = 1.5;
                    repetition_penalty = 1.0;
                    chat_template_kwargs = {
                      enable_thinking = false;
                    };
                  };
                };
              };
            };
          };
          hooks.on_startup.preload = [ "" ];
        };
      };
      systemd.services.llama-swap = {
        environment.XDG_CACHE_HOME = "/var/cache/llama.cpp";
        serviceConfig = {
          DynamicUser = lib.mkForce false;
          CacheDirectory = "llama.cpp";
          LimitMEMLOCK = "infinity";
        };
      };
    };
}
