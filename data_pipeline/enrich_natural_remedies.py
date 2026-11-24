#!/usr/bin/env python3
"""
Enriches offline_icar_protocols.json and Firestore seeder with verified ICAR/CIB&RC
naturalRemedySteps aligned with AgriSage Organics design specifications.
"""

import json
import os
import sys

def get_natural_remedy_steps(protocol_id: str, category: str, crop: str) -> list:
    lower_id = protocol_id.lower()
    
    # 1. Non-leaf background
    if lower_id == "not_a_leaf_background":
        return [
            {
                "stepNumber": 1,
                "title": {
                    "en": "Focus on Crop Foliage",
                    "hi": "फसल की पत्ती पर ध्यान केंद्रित करें",
                    "mr": "पिकाच्या पानावर कॅमेरा केंद्रित करा"
                },
                "instructions": {
                    "en": "Position the camera 15-20 cm above a single infected leaf with steady lighting.",
                    "hi": "स्थिर रोशनी में एकल संक्रमित पत्ती से 15-20 सेमी ऊपर कैमरा रखें।",
                    "mr": "चांगल्या प्रकाशात एकाच बाधित पानावर १५-२० सेमी अंतरावरून कॅमेरा धरा."
                },
                "dosage": "N/A",
                "timing": "Daylight hours",
                "ingredients": ["Clean camera lens"],
                "safetyPrecaution": {
                    "en": "Avoid harsh shadows or strong backlighting.",
                    "hi": "तेज छाया या चकाचौंध से बचें।",
                    "mr": "तीव्र सावली किंवा थेट सूर्यकिरणांचा चकाका टाळा."
                }
            }
        ]

    # 2. Healthy foliar profiles
    if lower_id.endswith("_healthy"):
        return [
            {
                "stepNumber": 1,
                "title": {
                    "en": "Preventive Jeevamrutha Foliar Immunity Spray",
                    "hi": "रोगनिरोधी जीवामृत पर्ण स्प्रे",
                    "mr": "प्रतिबंधक जीवामृत फवारणी (प्रतिकारशक्ती वाढ)"
                },
                "instructions": {
                    "en": "Prepare fresh aerated Jeevamrutha (cow dung, urine, jaggery, besan, fertile soil). Filter thoroughly through muslin cloth and spray across foliage to boost cuticle strength and beneficial microbiome.",
                    "hi": "ताजा जीवामृत तैयार करें, महीन कपड़े से छानकर पत्तियों पर स्प्रे करें ताकि रोग प्रतिरोधक क्षमता बढ़े।",
                    "mr": "ताजे गाळलेले जीवामृत (५-१०% द्रावण) पानांवर फवारा, ज्यामुळे पानांची रोगप्रतिकारशक्ती आणि सूक्ष्मजीव वाढतात."
                },
                "dosage": "100 ml per 10 L water (1:100 dilution) or 200 L/acre",
                "timing": "Early morning or late afternoon every 14 days",
                "ingredients": ["Fresh Cow Dung", "Cow Urine (Gomutra)", "Organic Jaggery", "Gram Flour (Besan)", "Living Forest/Farm Soil"],
                "safetyPrecaution": {
                    "en": "Use within 7 days of fermentation; do not store in airtight containers.",
                    "hi": "किण्वन के 7 दिनों के भीतर उपयोग करें।",
                    "mr": "आंबवल्यानंतर ७ दिवसांच्या आत वापरा; हवाबंद डब्यात ठेवू नका."
                }
            },
            {
                "stepNumber": 2,
                "title": {
                    "en": "Organic Mulching & Moisture Conservation",
                    "hi": "जैविक मल्चिंग और नमी संरक्षण",
                    "mr": "सेंद्रिय आच्छादन (मल्चिंग) आणि ओलावा जतन"
                },
                "instructions": {
                    "en": "Spread a 5-8 cm layer of dried crop residue, straw, or dry leaves around root zones to prevent soil splash and preserve mycorrhizal network.",
                    "hi": "जड़ों के आसपास सूखी घास या पत्तियों की 5-8 सेमी परत बिछाएं ताकि मिट्टी के छींटों से संक्रमण न फैले।",
                    "mr": "झाडांच्या मुळांभोवती ५-८ सेमी जाडीचे सुक्या गवताचे किंवा पालापाचोळ्याचे आच्छादन करा."
                },
                "dosage": "2-3 tonnes dried biomass per acre",
                "timing": "After irrigation or light weeding",
                "ingredients": ["Paddy Straw", "Sugarcane Trash", "Crushed Dry Leaves"],
                "safetyPrecaution": {
                    "en": "Ensure mulch material is free from active fungal spores or sclerotia.",
                    "hi": "सुनिश्चित करें कि पुआल में पहले से कोई फंगल संक्रमण न हो।",
                    "mr": "आच्छादनाचे साहित्य रोगमुक्त असल्याची खात्री करा."
                }
            }
        ]

    # 3. Abiotic Nutrient Deficiencies (6 classes)
    if lower_id.startswith("abiotic_"):
        return [
            {
                "stepNumber": 1,
                "title": {
                    "en": "Panchagavya Foliar Bio-Nutrient Spray",
                    "hi": "पंचगव्य पर्ण जैव-पोषक स्प्रे",
                    "mr": "पंचगव्य सेंद्रिय टॉनिक फवारणी (अन्नद्रव्य पूर्तता)"
                },
                "instructions": {
                    "en": "Dilute 300 ml filtered traditional Panchagavya in 10 L water (3% solution). Spray thoroughly on the upper and lower surfaces of leaves for immediate stomatal nutrient uptake.",
                    "hi": "10 लीटर पानी में 300 मिली पंचगव्य (3%) मिलाकर सुबह पत्तियों पर छिड़कें।",
                    "mr": "१० लिटर पाण्यात ३०० मिली गाळलेले पंचगव्य (३%) मिसळून पानांच्या वरच्या व खालच्या भागावर फवारा."
                },
                "dosage": "30 ml/L of water (3% foliar solution)",
                "timing": "Early morning before 9:00 AM",
                "ingredients": ["Cow Dung", "Cow Ghee", "Cow Milk", "Cow Curd", "Gomutra", "Sugarcane Juice", "Tender Coconut Water"],
                "safetyPrecaution": {
                    "en": "Do not spray during peak midday sunlight to avoid foliar scorch.",
                    "hi": "कड़क धूप में छिड़काव न करें।",
                    "mr": "कडक उन्हात फवारणी करू नका."
                }
            },
            {
                "stepNumber": 2,
                "title": {
                    "en": "Vermicompost Tea & Enriched Bio-Soil Drench",
                    "hi": "वर्मीकम्पोस्ट चाय और संवर्धित मिट्टी ड्रेंचिंग",
                    "mr": "गांडूळ खत अर्क (Vermiwash) आळवणी"
                },
                "instructions": {
                    "en": "Brew vermicompost in aerated water with 50g jaggery for 24 hours. Drench root zones to stimulate microbial mineral solubilization and balance cation exchange capacity.",
                    "hi": "वर्मीकम्पोस्ट को पानी में 24 घंटे भिगोकर जड़ क्षेत्र में ड्रेंचिंग करें।",
                    "mr": "वर्मीवॉश किंवा गांडूळ खताचा अर्क मुळांच्या कार्यक्षेत्रात आळवणी करा."
                },
                "dosage": "1 L vermiwash diluted in 5 L water per 20 plants",
                "timing": "During soil wetting or after drip irrigation",
                "ingredients": ["Pure Earthworm Vermicompost", "Vermiwash", "Organic Cane Jaggery"],
                "safetyPrecaution": {
                    "en": "Avoid waterlogging; ensure soil has adequate drainage.",
                    "hi": "जलभराव से बचें; जल निकासी की जांच करें।",
                    "mr": "वाफ्यात पाणी साचू देऊ नका; निचरा चांगला ठेवा."
                }
            },
            {
                "stepNumber": 3,
                "title": {
                    "en": "Targeted Mineral Amendment (Ash / Rock Phosphate / Zn-Biofertilizer)",
                    "hi": "लक्षित प्राकृतिक खनिज संशोधन",
                    "mr": "नैसर्गिक खनिज उपाय (लाकडी राख / PSB / झिंक बॅक्टेरिया)"
                },
                "instructions": {
                    "en": "For potassium/micronutrients: Apply sieved hardwood ash extract (rich in natural potassium carbonate) or Zinc-solubilizing bio-inoculant (ZSB @ 5g/L) to restore leaf chlorophyll.",
                    "hi": "पोटेशियम/जिंक की कमी के लिए लकड़ी की राख का अर्क या जिंक जीवाणु (ZSB) डालें।",
                    "mr": "पोटॅश किंवा झिंक कमतरतेसाठी लाकडाची चाळलेली राख किंवा झिंक विरघळवणारे जिवाणू वापरा."
                },
                "dosage": "500g wood ash dissolved in 10L water (strained) or 2.5 kg/ha ZSB biofertilizer",
                "timing": "Evening soil application",
                "ingredients": ["Sieved Wood Ash", "Zinc Solubilizing Bacteria (ZSB)", "Phosphate Solubilizing Bacteria (PSB)"],
                "safetyPrecaution": {
                    "en": "Maintain neutral soil pH; do not apply excessive wood ash to alkaline soils.",
                    "hi": "मिट्टी के पीएच का ध्यान रखें।",
                    "mr": "चोपण किंवा क्षारीय जमिनीत जास्त राख वापरू नका."
                }
            }
        ]

    # 4. Bacterial Infections
    if category.upper() == "BACTERIAL" or "bacterial" in lower_id:
        return [
            {
                "stepNumber": 1,
                "title": {
                    "en": "Pseudomonas fluorescens Bio-Bactericide Spray",
                    "hi": "स्यूडोमोनास फ्लोरोसेंस जैव-जीवाणुनाशक स्प्रे",
                    "mr": "स्यूडोमोनास फ्लोरोसन्स जैविक फवारणी (बॅक्टेरिया नियंत्रण)"
                },
                "instructions": {
                    "en": "Dissolve ICAR-certified Pseudomonas fluorescens powder (1x10^8 CFU/g) with jaggery in clean water. Incubate for 2 hours and spray across the entire foliage.",
                    "hi": "स्यूडोमोनास फ्लोरोसेंस (10 ग्राम/लीटर) को पानी में मिलाकर सुबह या शाम छिड़कें।",
                    "mr": "स्यूडोमोनास फ्लोरोसन्स (१० ग्रॅम/लिटर) गुळाच्या पाण्यात मिसळून पानांवर फवारा."
                },
                "dosage": "10 g/L of water or 2.5 kg/ha",
                "timing": "Early morning or overcast late afternoon",
                "ingredients": ["Pseudomonas fluorescens wettable powder", "Organic Jaggery (adhesive stimulant)"],
                "safetyPrecaution": {
                    "en": "Never mix bioagents with chemical bactericides or copper sprays.",
                    "hi": "इसे किसी भी रासायनिक दवा या कॉपर के साथ न मिलाएं।",
                    "mr": "कोणत्याही रासायनिक औषधासोबत किंवा तांबायुक्त बुरशीनाशकासोबत एकत्र करू नका."
                }
            },
            {
                "stepNumber": 2,
                "title": {
                    "en": "Fermented Garlic-Chili-Gomutra Biocide Extract",
                    "hi": "लहसुन-मिर्च-गोमूत्र अर्क स्प्रे",
                    "mr": "लसूण-मिरची-गोमूत्र अर्क (नैसर्गिक बॅक्टेरिया प्रतिबंधक)"
                },
                "instructions": {
                    "en": "Crush 500g fresh garlic and 500g pungent green chilies into 5L aged cow urine. Ferment for 48 hours, strain through double-layered cloth, and dilute for foliar spray.",
                    "hi": "लहसुन और तीखी मिर्च को गोमूत्र में 2 दिन भिगोकर छान लें और स्प्रे करें।",
                    "mr": "५०० ग्रॅम लसूण आणि ५०० ग्रॅम तिखट हिरवी मिरची ५ लिटर गोमूत्रात २ दिवस आंबवून गाळून फवारा."
                },
                "dosage": "20 ml per 1 L water (2% spray)",
                "timing": "Clear day in late afternoon",
                "ingredients": ["Desi Cow Urine", "Fresh Raw Garlic", "Spicy Green Chilies"],
                "safetyPrecaution": {
                    "en": "Wear gloves and eye protection while straining pungent extracts.",
                    "hi": "अर्क तैयार करते समय दस्ताने और चश्मा पहनें।",
                    "mr": "अर्क गाळताना डोळ्यांची आणि हातांची काळजी घ्या."
                }
            },
            {
                "stepNumber": 3,
                "title": {
                    "en": "Field Sanitation & Dry Ash Canopy Dusting",
                    "hi": "रोगग्रस्त पत्तियों की छंटाई और राख का बुरकाव",
                    "mr": "बाधित पाने छाटणे आणि सकाळच्या दवबिंदूंवर राखेची धुरळणी"
                },
                "instructions": {
                    "en": "Carefully snip off heavily blighted lower leaves with sterilized shears and bury outside field. Dust fine dry cow dung ash over remaining foliage during morning dew.",
                    "hi": "गंभीर रूप से सड़ी पत्तियों को काटकर खेत से दूर नष्ट करें और सुबह राख छिड़कें।",
                    "mr": "अतिबाधित पाने कापून शेताबाहेर जाळून नष्ट करा आणि सकाळी पानांवर कोरडी बारीक राख धुरळा."
                },
                "dosage": "5-10 kg fine dry ash per acre",
                "timing": "Early dawn while dew is on leaves",
                "ingredients": ["Sterilized Shears", "Fine Cow Dung Ash"],
                "safetyPrecaution": {
                    "en": "Disinfect pruning shears in 70% alcohol or boiling water between plants.",
                    "hi": "कैंची को हर पौधे के बाद रोगाणुमुक्त करें।",
                    "mr": "कातर प्रत्येक झाडानंतर निर्जंतुक करा."
                }
            }
        ]

    # 5. Viral Diseases & Insect Vectors
    if category.upper() == "VIRAL" or any(k in lower_id for k in ["virus", "curl", "mosaic", "tungro"]):
        return [
            {
                "stepNumber": 1,
                "title": {
                    "en": "Agniastra / Dashaparni Kashayam Botanical Vector Repellent",
                    "hi": "अग्निअस्त्र / दशपर्णी काढ़ा (सफेद मक्खी व कीट नियंत्रण)",
                    "mr": "अग्निअस्त्र / दशपर्णी काढा (व्हायरस प्रसारक पांढरी माशी व तुडतुडे नियंत्रण)"
                },
                "instructions": {
                    "en": "Boil crushed neem leaves, tobacco/karanj, green chili, garlic, and calotropis leaves in cow urine. Dilute the strained extract to repel whiteflies, aphids, and thrips vectoring the virus.",
                    "hi": "अग्निअस्त्र या दशपर्णी अर्क (25 मिली/लीटर) का छिड़काव करें ताकि कीट वायरस न फैला सकें।",
                    "mr": "अग्निअस्त्र किंवा दशपर्णी काढा (२०-२५ मिली/लिटर) फवारा, ज्यामुळे पांढरी माशी आणि तुडतुडे नष्ट होतात."
                },
                "dosage": "25 ml per 1 L water (2.5% foliar spray)",
                "timing": "Late afternoon every 7-10 days",
                "ingredients": ["Neem Leaves", "Karanj Leaves", "Calotropis (Rui)", "Cow Urine", "Garlic", "Green Chilies"],
                "safetyPrecaution": {
                    "en": "Do not exceed recommended concentration to avoid foliar phytotoxicity.",
                    "hi": "मात्रा अधिक न करें ताकि पत्तियां न जलें।",
                    "mr": "प्रमाण जास्त करू नका, अन्यथा पानांना इजा होऊ शकते."
                }
            },
            {
                "stepNumber": 2,
                "title": {
                    "en": "Yellow & Blue Sticky Traps Installation",
                    "hi": "पीले और नीले चिपचिपे ट्रैप की स्थापना",
                    "mr": "पिवळे व निळे चिकट सापळे बसवणे"
                },
                "instructions": {
                    "en": "Erect bright yellow sticky traps (targeting whiteflies and aphids) and blue sticky traps (targeting thrips) at crop canopy level across the field grid.",
                    "hi": "खेत में प्रति एकड़ 15-20 पीले और नीले स्टिकी ट्रैप लगाएं।",
                    "mr": "एकरला १५-२० पिवळे आणि निळे चिकट सापळे पिकाच्या उंचीवर लावा."
                },
                "dosage": "15 yellow + 10 blue traps per acre",
                "timing": "Immediate setup upon initial spotting",
                "ingredients": ["Weatherproof Yellow Sticky Sheets", "Blue Sticky Sheets", "Castor Oil / Entomological Glue", "Bamboo Stakes"],
                "safetyPrecaution": {
                    "en": "Replace sheets once covered by 70% insect debris.",
                    "hi": "शीट भरने पर बदल दें।",
                    "mr": "सापळे कीटकांनी भरल्यावर नवीन लावा."
                }
            },
            {
                "stepNumber": 3,
                "title": {
                    "en": "Sour Buttermilk & Raw Milk Viral Inhibition Spray",
                    "hi": "खट्टी छाछ और कच्चे दूध का एंटी-वायरल स्प्रे",
                    "mr": "आंबट ताक व कच्च्या दुधाची फवारणी (विषाणू अवरोधक)"
                },
                "instructions": {
                    "en": "Mix unboiled fresh raw milk or fermented sour buttermilk in water. The lactic proteins denature the external viral capsid and coat healthy leaves, preventing cell penetration.",
                    "hi": "कच्चा दूध (10%) या खट्टी छाछ (50 मिली/लीटर) मिलाकर पत्तियों पर छिड़कें।",
                    "mr": "१०% कच्चे दूध किंवा आंबट ताक (५० मिली/लिटर) पाण्यात मिसळून फवारा; दुधातील प्रथिने विषाणू वाढ रोखतात."
                },
                "dosage": "50 ml sour buttermilk or 100 ml raw milk per 1 L water",
                "timing": "Morning spray at 7-day intervals",
                "ingredients": ["Sour Cow Buttermilk (4-day fermented)", "Fresh Raw Cow Milk"],
                "safetyPrecaution": {
                    "en": "Use only fresh, preservative-free dairy products.",
                    "hi": "केवल ताजा, बिना मिलावट का दूध/छाछ उपयोग करें।",
                    "mr": "केवळ ताजे, भेसळ नसलेले ताक/दूध वापरा."
                }
            }
        ]

    # 6. Sucking Pests / Spider Mites
    if category.upper() == "PEST" or "mite" in lower_id:
        return [
            {
                "stepNumber": 1,
                "title": {
                    "en": "Beauveria bassiana / Verticillium lecanii Entomopathogenic Spray",
                    "hi": "ब्यूवेरिया बासियाना जैव-कीटनाशक स्प्रे",
                    "mr": "ब्युव्हेरिया बॅसियाना जैविक बुरशी फवारणी (कोळी व कीड नियंत्रण)"
                },
                "instructions": {
                    "en": "Mix wettable entomopathogenic fungal powder (1x10^8 spores/g) with jaggery water. Spray thoroughly onto leaf undersides where colonies dwell.",
                    "hi": "ब्यूवेरिया बासियाना (5 ग्राम/लीटर) को पत्तियों की निचली सतह पर अच्छी तरह स्प्रे करें।",
                    "mr": "ब्युव्हेरिया बॅसियाना (५ ग्रॅम/लिटर) पाठीमागील पानांवर जिथे लाल कोळी असतात तिथे पूर्ण ओले होईपर्यंत फवारा."
                },
                "dosage": "5 g/L of water or 2.5 kg/ha",
                "timing": "Late evening during high humidity (> 75%)",
                "ingredients": ["Beauveria bassiana WP", "Verticillium lecanii WP", "Organic Jaggery"],
                "safetyPrecaution": {
                    "en": "Do not expose spore mixture to direct sunlight or hot tank water.",
                    "hi": "मिश्रण को सीधी धूप से बचाएं।",
                    "mr": "द्रावणावर थेट ऊन पडू देऊ नका."
                }
            },
            {
                "stepNumber": 2,
                "title": {
                    "en": "Cold-Pressed Neem Oil (Azadirachtin 10,000 ppm) + Soap Emulsion",
                    "hi": "नीम का तेल (10,000 ppm) और जैविक साबुन इमल्शन",
                    "mr": "कडुलिंब अर्क / नीम तेल (१०,००० पीपीएम) फवारणी"
                },
                "instructions": {
                    "en": "Mix 5 ml cold-pressed neem oil with 1 ml liquid khadi soap or cow urine in a little warm water to form a milky white emulsion. Add remaining water and spray.",
                    "hi": "नीम का तेल (5 मिली/लीटर) और साबुन का घोल मिलाकर दूधिया घोल बनाएं और स्प्रे करें।",
                    "mr": "५ मिली नीम तेल आणि १ मिली खादी लिक्विड सोप कोमट पाण्यात एकत्र ढवळून दुधाळ द्रावण तयार करा व फवारा."
                },
                "dosage": "5 ml/L of water",
                "timing": "Early morning or late afternoon",
                "ingredients": ["Cold-Pressed Neem Oil (Azadirachtin)", "Organic Liquid Soap / Reetha Nut Extract"],
                "safetyPrecaution": {
                    "en": "Always pre-emulsify oil with soap; un-emulsified oil will separate and burn tender leaf edges.",
                    "hi": "तेल को साबुन के साथ अच्छी तरह घोलें।",
                    "mr": "तेल पाण्यात थेट टाकू नका; आधी साबणाने पूर्ण विरघळवून घ्या."
                }
            }
        ]

    # 7. Fungal Pathogens (Default for Blights, Rusts, Mildews, Leaf Spots, Wilts)
    return [
        {
            "stepNumber": 1,
            "title": {
                "en": "Trichoderma viride / harzianum Bio-Fungicide Inoculation",
                "hi": "ट्राइकोडर्मा विरिडी जैव-फफूंदनाशक स्प्रे",
                "mr": "ट्रायकोडर्मा व्हिरिडी जैविक बुरशीनाशक फवारणी"
            },
            "instructions": {
                "en": "Mix Trichoderma viride wettable powder (2x10^8 CFU/g) in water with 100g jaggery. Incubate in shade for 4 hours to activate resting spores, then apply as foliar spray and root collar drench.",
                "hi": "ट्राइकोडर्मा विरिडी (5 ग्राम/लीटर) को गुड़ के पानी में 4 घंटे रखकर पत्तियों और जड़ों के पास स्प्रे करें।",
                "mr": "ट्रायकोडर्मा व्हिरिडी (५ ग्रॅम/लिटर) गुळाच्या पाण्यात ४ तास भिजवून पानांवर आणि खोडाभोवती फवारा."
            },
            "dosage": "5 g/L of water or 2.5 kg/ha",
            "timing": "Overcast day or late afternoon",
            "ingredients": ["Trichoderma viride / harzianum WP", "Organic Sugarcane Jaggery"],
            "safetyPrecaution": {
                "en": "Maintain 7-day interval before or after applying any chemical fungicide.",
                "hi": "रासायनिक फफूंदनाशक डालने के 7 दिन पहले या बाद ही उपयोग करें।",
                "mr": "कोणत्याही रासायनिक बुरशीनाशकाच्या ७ दिवस आधी किंवा नंतरच वापरा."
            }
        },
        {
            "stepNumber": 2,
            "title": {
                "en": "Fermented Copper-Steeped Sour Buttermilk (Tamra Takra)",
                "hi": "तांबे के बर्तन में रखी खट्टी छाछ (ताम्र तक्र) स्प्रे",
                "mr": "तांब्याच्या भांड्यातील आंबट ताक (ताम्र ताक) फवारणी"
            },
            "instructions": {
                "en": "Pour 5 L sour cow buttermilk into a copper vessel (or place a clean copper wire/plate in an earthen pot). Ferment for 5-7 days until a greenish-blue hue develops. Strain and dilute 1:10 with water.",
                "hi": "तांबे के बर्तन में 5 दिन रखी खट्टी छाछ को 1:10 अनुपात में पानी मिलाकर पत्तियों पर छिड़कें।",
                "mr": "तांब्याची तार किंवा भांडे वापरून ५ दिवस आंबवलेले ताक १० पटीने पाण्यात मिसळून फवारा; हे नैसर्गिक कॉपर बुरशीनाशकाचे काम करते."
            },
            "dosage": "50 ml per 1 L water (5% foliar spray)",
            "timing": "Early morning before temperature rises",
            "ingredients": ["Sour Desi Cow Buttermilk", "Clean Copper Plate/Wire", "Earthen Pot"],
            "safetyPrecaution": {
                "en": "Filter through a fine 100-mesh nylon strainer to avoid clogging backpack sprayer nozzles.",
                "hi": "स्प्रेयर की नोजल जाम न हो इसलिए महीन कपड़े से दो बार छानें।",
                "mr": "पंपाचे नोझल चोक होऊ नये म्हणून बारीक नायलॉनच्या कपड्याने गाळून घ्या."
            }
        },
        {
            "stepNumber": 3,
            "title": {
                "en": "Neem Oil Anti-Sporulant Barrier Spray",
                "hi": "नीम तेल एंटी-स्पोरुलेंट सुरक्षा स्प्रे",
                "mr": "कडुलिंब तेल बीजाणू प्रतिबंधक आवरण फवारणी"
            },
            "instructions": {
                "en": "Emulsify 5 ml neem oil with mild soap in 1 L water. Apply to both sides of foliage to coat mycelia and physically inhibit secondary spore germination and wind dispersal.",
                "hi": "नीम का तेल (5 मिली/लीटर) पत्तियों के दोनों तरफ स्प्रे करें ताकि फंगल बीजाणु हवा से न फैलें।",
                "mr": "५ मिली नीम तेल पानांच्या दोन्ही बाजूंवर फवारा, ज्यामुळे बुरशीचे नवीन बीजाणू तयार होणे आणि वाऱ्याने पसरणे थांबते."
            },
            "dosage": "5 ml/L of water",
            "timing": "Late afternoon every 10 days until new growth emerges healthy",
            "ingredients": ["Pure Cold-Pressed Neem Seed Oil (3000-10000 ppm)", "Organic Emulsifier"],
            "safetyPrecaution": {
                "en": "Do not spray immediately before anticipated heavy rainfall.",
                "hi": "भारी बारिश की संभावना से ठीक पहले स्प्रे न करें।",
                "mr": "मुसळधार पाऊस पडण्याची शक्यता असताना फवारणी करू नका."
            }
        }
    ]

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    protocols_path = os.path.join(base_dir, "assets", "data", "offline_icar_protocols.json")
    
    if not os.path.exists(protocols_path):
        print(f"Error: Could not find {protocols_path}")
        sys.exit(1)
        
    with open(protocols_path, "r", encoding="utf-8") as f:
        protocols = json.load(f)
        
    print(f"Loaded {len(protocols)} protocols from {protocols_path}")
    
    enriched_count = 0
    for p in protocols:
        p_id = p.get("id", "")
        category = p.get("category", "")
        crops = p.get("affectedCrops", [])
        crop = crops[0] if crops else "General"
        
        remedy_steps = get_natural_remedy_steps(p_id, category, crop)
        p["naturalRemedySteps"] = remedy_steps
        enriched_count += 1
        
    with open(protocols_path, "w", encoding="utf-8") as f:
        json.dump(protocols, f, indent=2, ensure_ascii=False)
        
    print(f"Successfully enriched {enriched_count} protocols with naturalRemedySteps in {protocols_path}!")

if __name__ == "__main__":
    main()
