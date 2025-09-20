# AI-Driven E-Commerce Platform for Personalized Skincare Recommendations

A comprehensive AI-powered platform that provides personalized skincare recommendations through remote skin analysis, combining computer vision, machine learning, and e-commerce functionality.

## 🔬 Research Project

This project was developed as part of a BSc (Hons) Computer Science dissertation at NSBM Green University, investigating how AI technologies can enhance personalized skincare product selection through objective skin condition assessment and intelligent recommendation systems.

## ✨ Features

### 🤖 AI-Powered Skin Analysis
- Real-time facial image analysis using EfficientNet-based CNN models
- Skin condition detection (acne, dryness, oiliness, hyperpigmentation)
- Confidence scoring and detailed analysis explanations
- Support for diverse skin tones and demographics

### 🎯 Personalized Recommendations
- Hybrid recommendation system combining collaborative and content-based filtering
- Product suggestions based on AI analysis results and user preferences
- Continuous learning from user feedback and interactions
- Explanation mechanisms for recommendation transparency

### 🛒 Integrated E-Commerce
- Complete online shopping functionality
- Product catalog with detailed information and ingredients
- Shopping cart, checkout, and order management
- Admin dashboard for system management

### 📱 Cross-Platform Applications
- **Mobile App**: Flutter-based iOS/Android application
- **Web Platform**: React-based responsive web interface
- **Admin Panel**: Comprehensive management dashboard

## 🛠 Tech Stack

### Backend
- **Framework**: Flask (Python)
- **Database**: MongoDB with GridFS
- **Caching**: Redis
- **Authentication**: JWT with refresh tokens
- **Background Tasks**: Celery
- **API**: RESTful with OpenAPI specification

### Frontend
- **Mobile**: Flutter/Dart with Riverpod state management
- **Web**: React with TypeScript and Redux Toolkit
- **Navigation**: go_router (mobile), React Router (web)
- **HTTP Client**: Dio (mobile), Axios (web)

### AI/ML
- **Framework**: TensorFlow/Keras
- **Models**: EfficientNet-B3 with custom classification heads
- **Deployment**: TensorFlow Serving with Docker
- **Training**: Transfer learning on dermatological datasets
- **Computer Vision**: OpenCV for image preprocessing

### Infrastructure
- **Containerization**: Docker
- **Development**: Kaggle for model training
- **Testing**: Genymotion for mobile emulation
- **Monitoring**: Structured logging with performance metrics

## 🏗 Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   Mobile App    │    │   Web App       │
│   (Flutter)     │    │   (React)       │
└─────────┬───────┘    └─────────┬───────┘
          │                      │
          └──────────┬───────────┘
                     │
            ┌────────▼────────┐
            │   API Gateway   │
            │   (Flask)       │
            └─────────┬───────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
┌───────▼──────┐ ┌────▼─────┐ ┌────▼──────┐
│ AI Analysis  │ │ Recommend│ │ E-commerce│
│ Service      │ │ Engine   │ │ Service   │
└──────┬───────┘ └────┬─────┘ └────┬──────┘
       │              │            │
┌──────▼──────┐ ┌─────▼─────┐ ┌────▼──────┐
│ TensorFlow  │ │ ML Models │ │ MongoDB   │
│ Serving     │ │ & Cache   │ │ Database  │
└─────────────┘ └───────────┘ └───────────┘
```

## 🚀 Getting Started

### Prerequisites
- Python 3.9+
- Node.js 18+
- Flutter SDK 3.10+
- MongoDB 6.0+
- Redis 7.0+
- Docker (optional)

### Backend Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/ai-skincare-platform.git
cd ai-skincare-platform
```

2. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install Python dependencies:
```bash
cd backend
pip install -r requirements.txt
```

4. Set environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

5. Start services:
```bash
# Start MongoDB and Redis
docker-compose up -d mongodb redis

# Run Flask application
python app.py
```

### Mobile App Setup

1. Install Flutter dependencies:
```bash
cd mobile
flutter pub get
```

2. Configure environment:
```bash
cp lib/config/config.example.dart lib/config/config.dart
# Update API endpoints and configuration
```

3. Run the application:
```bash
flutter run
```

### Web App Setup

1. Install Node.js dependencies:
```bash
cd web
npm install
```

2. Configure environment:
```bash
cp .env.example .env.local
# Update API endpoints
```

3. Start development server:
```bash
npm run dev
```

### Admin Dashboard

Access the admin dashboard at `http://localhost:3000/admin` with admin credentials.

## 📊 AI Model Training

The skin analysis models are trained using the following process:

1. **Dataset Preparation**: 
   - FitzPatrick17k dataset for diverse skin representation
   - Custom augmentation pipeline for robustness

2. **Model Architecture**:
   - EfficientNet-B3 backbone with transfer learning
   - Custom classification heads for different skin conditions
   - Mixed precision training for efficiency

3. **Training Process**:
   ```python
   # Example training command
   python train_model.py --dataset fitzpatrick17k --model efficientnet-b3 --epochs 50
   ```

4. **Model Evaluation**:
   - Achieved 87.3% overall accuracy
   - Balanced performance across demographic groups
   - Real-time inference under 3.2 seconds

## 📱 Mobile App Screenshots

The mobile application provides an intuitive interface for:
- Skin analysis with camera integration
- Personalized recommendations display
- Product browsing and purchasing
- User profile and history management

## 🔧 Admin Dashboard Features

- **User Management**: View and manage user accounts
- **Product Catalog**: Add, edit, and organize products
- **Order Processing**: Track and manage customer orders
- **Analytics**: Monitor system performance and user behavior
- **Content Management**: Update categories and attributes

## 🧪 Testing

### Running Tests
```bash
# Backend tests
cd backend
pytest tests/

# Frontend tests  
cd web
npm test

# Mobile tests
cd mobile
flutter test
```

### Performance Testing
- Load testing supports 100+ concurrent users
- Average API response time: <200ms
- Mobile app analysis time: ~3.2 seconds

## 📈 Performance Metrics

### AI Model Performance
- **Accuracy**: 87.3% overall
- **Precision**: 88.1% macro-averaged
- **Recall**: 87.6% macro-averaged
- **F1-Score**: 87.8% macro-averaged

### User Experience Results
- **Task Completion Rate**: 94%
- **User Satisfaction**: 4.2/5.0
- **Trust in AI**: 78% confidence rate
- **Recommendation Relevance**: 76% accuracy

### System Performance
- **Response Time**: <3 seconds for analysis
- **Uptime**: 99.7% reliability
- **Concurrent Users**: 100+ supported
- **Mobile Performance**: 2.1s average load time

## 🤝 Contributing

This is a research project developed for academic purposes. If you're interested in contributing or have questions about the implementation:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request with detailed description

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🎓 Academic Context

This platform was developed as part of academic research investigating AI applications in personalized consumer recommendations. The research methodology, evaluation results, and technical implementation details are documented in the accompanying dissertation.

### Research Objectives
- Develop accurate AI-powered skin condition analysis
- Create effective personalized recommendation algorithms
- Evaluate user acceptance of AI-driven skincare guidance
- Demonstrate integration feasibility of AI with e-commerce

### Key Contributions
- Novel hybrid recommendation system for skincare products
- Bias-mitigated AI models for diverse demographic groups
- Comprehensive evaluation methodology for AI consumer applications
- Open-source implementation for further research

## 📞 Contact

**Author**: P.S.A.T Lakshani  
**Institution**: NSBM Green University  
**Email**: [thilakshi.samaraweera2698@gmail.com]

For technical questions or research collaboration inquiries, please open an issue or contact the author directly.

## 🙏 Acknowledgments

- NSBM Green University Faculty of Computing for research support
- 150 user study participants for valuable feedback
- Open-source community for frameworks and datasets
- Research supervisors for guidance and expertise

## 📚 Related Publications

If you use this work in your research, please cite:

```bibtex
@mastersthesis{lakshani2025ai,
  title={Development of an AI-Driven E-Commerce Platform for Personalized Skincare Recommendations and Remote Skin Analysis},
  author={Lakshani, P.S.A.T},
  year={2025},
  school={NSBM Green University},
  type={BSc (Hons) Computer Science Dissertation}
}
```

---

*This project demonstrates the practical application of artificial intelligence in consumer-facing applications while maintaining focus on user experience, privacy protection, and inclusive design principles.*
